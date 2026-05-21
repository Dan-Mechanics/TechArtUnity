// Attach to any GameObject in a URP scene
//
// Frame loop:
//   1. Zero _MassGrid
//   2. Dispatch BuildMassGrid  (particles -> voxels)
//   3. Dispatch SimulateGravity (voxels + planet -> new particle state)
//   5. DrawMeshInstancedIndirect (particles) + DrawMesh (planet)

using System.Runtime.InteropServices;
using UnityEngine;

[ExecuteAlways]
public class GravitySimulator : MonoBehaviour
{
    // ── Inspector ────────────────────────────────────────────────────────────
    [Header("Simulation")]
    [Tooltip("Total number of particles.")]
    public int particleCount = 1_000_000;

    [Tooltip("Gravitational constant. Try 0.05 – 0.5.")]
    public float gravity = 0.1f;

    [Tooltip("Softening length squared — prevents singularity at r=0.")]
    public float softening = 0.5f;

    [Tooltip("Velocity damping per step (1 = no damping, 0.9999 = gentle spiral-in).")]
    [Range(0.99f, 1f)]
    public float damping = 0.9999f;

    [Header("Voxel Grid")]
    [Tooltip("World-space centre of the simulation volume.")]
    public Vector3 gridCenter = Vector3.zero;

    [Tooltip("World-space size of each axis of the simulation cube.")]
    public float gridExtent = 200f;   // total side length

    [Header("Spawn")]
    [Tooltip("Radius of the initial particle disc (should fit inside gridExtent/2).")]
    public float spawnRadius = 80f;

    [Tooltip("Orbital speed multiplier at spawn (1 = circular, >1.4 = escape).")]
    public float initialOrbitalSpeed = 1.2f;

    [Tooltip("Particle mass range.")]
    public float massMin = 0.5f;
    public float massMax = 3.0f;

    [Header("Planet")]
    public Vector3 planetPosition = Vector3.zero;

    [Tooltip("Planet mass. Much larger than particle masses.")]
    public float planetMass = 100_000f;

    [Tooltip("Extra visual scale for the planet billboard.")]
    public float planetVisualScale = 1f;

    [Header("Rendering")]
    public ComputeShader computeShader;
    public Shader      particleShader;
    public Shader      planetShader;

    [Tooltip("Visual radius = sqrt(mass) * massScale.")]
    public float massScale = 0.04f;

    private Material particleMaterial, planetMaterial;
    
    //  Particle struct: 32 bytes, matches HLSL struct exactly
    [StructLayout(LayoutKind.Sequential)]
    struct Particle
    {
        public Vector3 position;   // 12
        public Vector3 velocity;   // 12
        public float   mass;       //  4
        public float   _pad;       //  4
    }

    const int GRID_RES   = 16;
    const int GRID_CELLS = GRID_RES * GRID_RES * GRID_RES;   // 4096

    ComputeBuffer _particleBuffer;

    ComputeBuffer _massGrid;          // uint[4096] — zeroed every frame
    uint[]        _zeroGrid;          // CPU-side zeroed array for fast reset

    ComputeBuffer _argsBuffer;
    uint[]        _args = new uint[5];

    Mesh          _quadMesh;
    Mesh          _planetQuad;

    int           _kernelBuild;
    int           _kernelSimulate;

    bool          _initialised;

    // Lifecycle
    void OnEnable()    => Initialise();
    void OnDisable()   => Release();
    void OnValidate()  { if (_initialised) { Release(); Initialise(); } }

    void Update()
    {
        if (!_initialised) return;
        Simulate();
        Render();
    }

    // Initialise
    void Initialise()
    {
        if (computeShader == null || planetShader == null || particleShader == null)
            return;

        particleMaterial = new Material(particleShader) { hideFlags = HideFlags.HideAndDontSave };
        planetMaterial = new Material(planetShader) { hideFlags = HideFlags.HideAndDontSave };

        _kernelBuild    = computeShader.FindKernel("BuildMassGrid");
        _kernelSimulate = computeShader.FindKernel("SimulateGravity");

        // Particle data
        Particle[] particles = new Particle[particleCount];
        for (int i = 0; i < particleCount; i++)
        {
            float   mass  = Random.Range(massMin, massMax);
            float   angle = Random.Range(0f, Mathf.PI * 2f);
            float   r     = Mathf.Sqrt(Random.value) * spawnRadius;
            float   h     = Random.Range(-spawnRadius * 0.02f, spawnRadius * 0.02f);

            Vector3 pos   = planetPosition + new Vector3(
                                Mathf.Cos(angle) * r, h, Mathf.Sin(angle) * r);

            Vector3 toCenter = planetPosition - pos;
            toCenter.y = 0f;
            float   dist = toCenter.magnitude + 0.001f;
            float   vCirc = Mathf.Sqrt(gravity * planetMass / dist);
            Vector3 tang  = Vector3.Cross(toCenter.normalized, Vector3.up).normalized;

            particles[i] = new Particle
            {
                position = pos,
                velocity = tang * vCirc * initialOrbitalSpeed,
                mass     = mass
            };
        }

        // Setup Particles ComputeBuffer
        int stride = Marshal.SizeOf<Particle>(); // 32
        _particleBuffer = new ComputeBuffer(particleCount, stride);
        _particleBuffer.SetData(particles);

        // Mass grid
        _massGrid  = new ComputeBuffer(GRID_CELLS, sizeof(uint));
        _zeroGrid  = new uint[GRID_CELLS];   // all zeros, reused every frame

        // Quad meshes
        _quadMesh = CreateQuad();
        _planetQuad = CreateQuad();

        // Indirect args, for rendering many particles using DrawMeshInstancedIndirect
        //  Maps to: D3D11_DRAW_INDEXED_INSTANCED_INDIRECT_ARGS 
        _argsBuffer = new ComputeBuffer(1, 5 * sizeof(uint),
                          ComputeBufferType.IndirectArguments);
        _args[0] = _quadMesh.GetIndexCount(0);                  // how many indices per instance (for subMesh 0)
        _args[1] = (uint)particleCount;                         // how many instances
        _args[2] = 0; // _quadMesh.GetIndexStart(0);            // offset in data, probably 0 for 1 mesh
        _args[3] = 0; // (uint)_quadMesh.GetBaseVertex(0);      // offset for vertex read (0 in this case too)
        _args[4] = 0;                                           // start instance location -> 0
        _argsBuffer.SetData(_args);
        
        _initialised = true;
    }
    
    void Simulate()
    {
        int groups = Mathf.CeilToInt(particleCount / 256f);

        // Shared uniforms for both kernels
        Vector3 gridMin  = gridCenter - Vector3.one * (gridExtent * 0.5f);
        Vector3 gridSize = Vector3.one * gridExtent;

        // Local function for ease of use
        void SetShared(int kernel)
        {
            computeShader.SetBuffer(kernel, "_Particles",  _particleBuffer);
            computeShader.SetBuffer(kernel, "_MassGrid", _massGrid);
            computeShader.SetVector("_GridMin",  gridMin);
            computeShader.SetVector("_GridSize", gridSize);
            computeShader.SetInt("_ParticleCount", particleCount);
        }

        // Pass 1: zero grid, then build
        _massGrid.SetData(_zeroGrid);            // CPU -> GPU zero (16KB, very fast)

        SetShared(_kernelBuild);
        computeShader.Dispatch(_kernelBuild, groups, 1, 1);

        // Pass 2: simulate
        SetShared(_kernelSimulate);
        computeShader.SetBuffer(_kernelSimulate, "_ParticlesWrite", _particleBuffer);
        computeShader.SetFloat("_DeltaTime",       Time.deltaTime);
        computeShader.SetFloat("_Gravity",         gravity);
        computeShader.SetFloat("_Softening",       softening);
        computeShader.SetFloat("_Damping",         damping);
        computeShader.SetVector("_PlanetPosition", planetPosition);
        computeShader.SetFloat("_PlanetMass",      planetMass);

        computeShader.Dispatch(_kernelSimulate, groups, 1, 1);
    }
    
    void Render()
    {
        particleMaterial.SetBuffer("_Particles", _particleBuffer);
        particleMaterial.SetFloat("_MassScale", massScale);
        particleMaterial.SetFloat("_MaxMass",   massMax);

        Bounds bounds = new Bounds(gridCenter, Vector3.one * gridExtent * 2f);
        Graphics.DrawMeshInstancedIndirect(
            _quadMesh, 0, particleMaterial, bounds, _argsBuffer);

        // Planet
        float planetRadius = Mathf.Sqrt(planetMass) * massScale * planetVisualScale;
        planetMaterial.SetFloat("_Radius", planetRadius);
        Graphics.DrawMesh(_planetQuad,
            Matrix4x4.TRS(planetPosition, Quaternion.identity, Vector3.one),
            planetMaterial, 0);
    }

    void Release()
    {
        _particleBuffer?.Release();    _particleBuffer    = null;
        _massGrid?.Release();   _massGrid   = null;
        _argsBuffer?.Release(); _argsBuffer = null;
        _initialised = false;
    }
    
    // Helper Function
    static Mesh CreateQuad()
    {
        var mesh = new Mesh
        {
            vertices  = new[] {
                new Vector3(-0.5f, -0.5f, 0f),
                new Vector3( 0.5f, -0.5f, 0f),
                new Vector3( 0.5f,  0.5f, 0f),
                new Vector3(-0.5f,  0.5f, 0f),
            },
            uv        = new[] {
                new Vector2(0, 0), new Vector2(1, 0),
                new Vector2(1, 1), new Vector2(0, 1),
            },
            triangles = new[] { 0, 1, 2, 0, 2, 3 }
        };
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();
        return mesh;
    }

    // Draw mass grid in Scene View
    void OnDrawGizmosSelected()
    {
        Gizmos.color = new Color(0.3f, 0.8f, 1f, 0.25f);
        Gizmos.DrawWireCube(gridCenter, Vector3.one * gridExtent);

        // Draw individual voxel lines at lower opacity
        Gizmos.color = new Color(0.3f, 0.8f, 1f, 0.06f);
        float cellSize = gridExtent / GRID_RES;
        Vector3 origin = gridCenter - Vector3.one * gridExtent * 0.5f;
        for (int i = 0; i <= GRID_RES; i++)
        for (int j = 0; j <= GRID_RES; j++)
        {
            // X-axis lines
            Gizmos.DrawLine(
                origin + new Vector3(0,            i * cellSize, j * cellSize),
                origin + new Vector3(gridExtent,   i * cellSize, j * cellSize));
            // Z-axis lines
            Gizmos.DrawLine(
                origin + new Vector3(i * cellSize, j * cellSize, 0),
                origin + new Vector3(i * cellSize, j * cellSize, gridExtent));
        }
    }
}
