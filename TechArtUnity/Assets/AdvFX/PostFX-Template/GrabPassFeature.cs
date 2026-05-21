using UnityEngine;
using UnityEngine.Rendering.Universal;

public class GrabPassFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public RenderTexture target;
    }

    public Settings settings = new();
    GrabPass _pass;

    public override void Create()
    {
        _pass = new GrabPass(settings.target);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
                                         ref RenderingData data)
    {
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {

    }
}