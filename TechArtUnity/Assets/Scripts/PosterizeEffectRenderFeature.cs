using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

/// <summary>
/// https://www.youtube.com/watch?v=U8PygjYAF7A
/// </summary>
public class PosterizeEffectRenderFeature : ScriptableRendererFeature
{
    private class PosterizeEffectPass : ScriptableRenderPass
    {
        private const string PASS_NAME = nameof(PosterizeEffectPass);
        private Material blitMaterial;

        public void Setup(Material blitMaterial)
        {
            this.blitMaterial = blitMaterial;
            requiresIntermediateTexture = true;
        }

        // This class stores the data needed by the RenderGraph pass.
        // It is passed as a parameter to the delegate function that executes the RenderGraph pass.
        private class PassData
        {
        }

        // RecordRenderGraph is where the RenderGraph handle can be accessed, through which render passes can be added to the graph.
        // FrameData is a context container through which URP resources can be accessed and managed.
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            var stack = VolumeManager.instance.stack;
            var customEffect = stack.GetComponent<VolumeComponent>();
            if (!customEffect.active)
                return;

            var resourceData = frameData.Get<UniversalResourceData>();
            if (resourceData.isActiveTargetBackBuffer)
            {
                Debug.LogError("if (resourceData.isActiveTargetBackBuffer)");
                return;
            }

            var source = resourceData.activeColorTexture;

            var destinationDesc = renderGraph.GetTextureDesc(source);
            destinationDesc.name = $"CameraColor-{PASS_NAME}";
            destinationDesc.clearBuffer = false;

            TextureHandle destination = renderGraph.CreateTexture(destinationDesc);

            var param = new RenderGraphUtils.BlitMaterialParameters(source, destination, blitMaterial, 0);
            renderGraph.AddBlitPass(param, passName: PASS_NAME);
            resourceData.cameraColor = destination;
        }
    }

    private PosterizeEffectPass scriptablePass;

    public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
    public Material material;

    /// <inheritdoc/>
    public override void Create()
    {
        scriptablePass = new PosterizeEffectPass();

        // Configures where the render pass should be injected.
        scriptablePass.renderPassEvent = injectionPoint;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (material == null)
        {
            Debug.LogWarning("if (material == null)");
            return;
        }

        scriptablePass.Setup(material);
        renderer.EnqueuePass(scriptablePass);
    }
}
