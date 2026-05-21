using UnityEngine;
using UnityEngine.Rendering;

public class DrawIntoRT : MonoBehaviour
{
    public RenderTexture rt, rt2;
    public Texture2D brush;
    public Color brushColor;

    [Range(0.01f, 1f)]
    public float scale = 1f;

    [Range(0.01f, 0.5f)]
    public float stampBias = 0.1f;

    [Range(0f, 1f)]
    public float hardness = 1f;

    public Shader brushShader;
    public Material targetMaterial;
    public string targetMaterialProperty;

    private Material brushMaterial;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        // No need to have Materials all over your project
        brushMaterial = new Material(brushShader);

        // Might want to clean these up adequately OnDestroy
        if (rt == null)
        {
            rt = new RenderTexture(Screen.width, Screen.height, 0);
            rt.Create();
        }

        if (rt2 == null)
        {
            rt2 = new RenderTexture(Screen.width, Screen.height, 0);
            rt2.Create();
        }
        
        // In case it hasn't been initialized
        RTHandles.Initialize(Screen.width, Screen.height);
        ClearTargets();
    }

    void ClearTargets()
    {
        Graphics.SetRenderTarget(rt);
        GL.Clear(true, true, Color.black);
        Graphics.SetRenderTarget(rt2);
        GL.Clear(true, true, Color.black);
        Graphics.SetRenderTarget(null);
    }

    void Update()
    {
        scale += Input.mouseScrollDelta.y * .025f;
        scale = Mathf.Clamp(scale, 0.01f, 1f);

        if (Input.GetMouseButtonDown(1))
            ClearTargets();

        if (Input.GetMouseButton(0))
        {
            /*
            // BASIC MODE
            Vector2 UV = Camera.main.ScreenToViewportPoint(Input.mousePosition);
            
            Vector2 aspect;
            aspect.x = Screen.width / Screen.height;
            aspect.y = 1;

            brush.wrapMode = TextureWrapMode.Clamp;
            Graphics.Blit(brush, rt, Vector2.one * aspect / scale, - UV * aspect / scale + Vector2.one * .5f);
            */

            // COMPLEX MODE
            Vector2 normalizedScreenUV;
            normalizedScreenUV.x = Input.mousePosition.x / Screen.width;
            normalizedScreenUV.y = Input.mousePosition.y / Screen.height;

            brushMaterial.SetFloat("_BrushSize", scale);
            brushMaterial.SetTexture("_BrushTex", brush);
            brushMaterial.SetColor("_BrushColor", brushColor);
            brushMaterial.SetVector("_BrushPos", normalizedScreenUV);
            brushMaterial.SetFloat("_StampBias", stampBias);
            brushMaterial.SetFloat("_Hardness", hardness);

            var cmd = CommandBufferPool.Get("BrushPaint");

            // We might be able to store these to prevent recreating them
            var src = RTHandles.Alloc(rt);
            var dst = RTHandles.Alloc(rt2);

            Blitter.BlitCameraTexture(
                cmd,
                src,
                dst,
                brushMaterial,
                0
            );
            Graphics.ExecuteCommandBuffer(cmd);

            // swap
            (rt, rt2) = (rt2, rt);

            // Assign to target
            targetMaterial.SetTexture(targetMaterialProperty, rt2);
        }
    }
}
