using UnityEngine;
using UnityEngine.Rendering.Universal;

public class GrayscaleFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        
    }

    public Settings settings = new();
    GrayscalePass _pass;

    public override void Create()
    {
        _pass = new GrayscalePass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
                                         ref RenderingData data)
    {
        // Skip in editor scene view if you want
        if (data.cameraData.cameraType == CameraType.Preview) return;

        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {

    }
}