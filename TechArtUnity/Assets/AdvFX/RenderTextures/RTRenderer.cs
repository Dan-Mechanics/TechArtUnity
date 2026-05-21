using UnityEngine;

/// <summary>
/// Renders a single vertex-colored triangle into a RenderTexture each frame.
/// Assign a RenderTexture asset to <see cref="renderTarget"/> in the Inspector,
/// then display it on a RawImage, material, or any surface you like.
/// No external shader asset or material is required — both are created at runtime.
/// </summary>
[ExecuteAlways]
public class RTRenderer : MonoBehaviour
{
    public RenderTexture renderTarget;

    /// <summary>Clip-space positions of the three vertices (Z=0, W=1).</summary>
    private static readonly Vector3[] Positions =
    {
        new Vector3( 0.0f,  1f, 0.5f),   // top   — red
        new Vector3( 1f, -1f, 0.5f),   // right — green
        new Vector3(-1f, -1f, 0.5f),   // left  — blue
    };

    /// <summary>Per-vertex colors (must match <see cref="Positions"/> length).</summary>
    private static readonly Color[] VertexColors =
    {
        Color.red,
        Color.green,
        Color.blue,
    };

    // -----------------------------------------------------------------------
    // Runtime objects — created once, reused every frame.
    // -----------------------------------------------------------------------
    private Material _material;
    private Mesh _mesh;

    private void OnEnable()
    {
        BuildMeshAndMaterial();
    }

    private void OnDisable()
    {
        DestroyRuntimeObjects();
    }

    private void LateUpdate()
    {
        if (renderTarget == null || _material == null || _mesh == null)
            return;

        // Blit the triangle into the render target.
        var previousRT = RenderTexture.active;
        RenderTexture.active = renderTarget;

        // Clear to black so old frames don't bleed through.
        GL.Clear(clearDepth: true, clearColor: true, Color.black);
        
        GL.PushMatrix();
        GL.LoadIdentity();
        GL.LoadProjectionMatrix(Matrix4x4.identity);

        _material.SetPass(0);
        // Causes distortions based on camera view
        //Graphics.DrawMeshNow(_mesh, Matrix4x4.identity);

        GL.Begin(GL.TRIANGLES);
        
        GL.Color(VertexColors[0]);
        GL.Vertex(Positions[0]);

        GL.Color(VertexColors[1]);
        GL.Vertex(Positions[1]);

        GL.Color(VertexColors[2]);
        GL.Vertex(Positions[2]);

        GL.End();

        GL.PopMatrix();

        // Graphics.DrawMeshNow(_mesh, transform.localToWorldMatrix);

        RenderTexture.active = previousRT;
    }

    private void BuildMeshAndMaterial()
    {
        // Shader / Material
        var shader = Shader.Find("Custom/VertexColored");

        if (shader == null)
        {
            Debug.LogError("Shader not found", this);
            return;
        }

        _material = new Material(shader) { hideFlags = HideFlags.HideAndDontSave };

        // Mesh
        _mesh = new Mesh { hideFlags = HideFlags.HideAndDontSave, name = "Triangle" };

        // The shader expects clip-space coords, so we pass them as "local"
        // positions and use an identity matrix in DrawMeshNow — Unity will
        // not apply any MVP transform because we skip it in the vertex shader.
        _mesh.SetVertices(Positions);
        _mesh.SetColors(VertexColors);
        _mesh.SetIndices(new[] { 0, 1, 2 }, MeshTopology.Triangles, 0);
        _mesh.UploadMeshData(markNoLongerReadable: false);
    }

    private void DestroyRuntimeObjects()
    {
        if (_material != null) DestroyImmediate(_material);
        if (_mesh != null) DestroyImmediate(_mesh);
        _material = null;
        _mesh = null;
    }
}