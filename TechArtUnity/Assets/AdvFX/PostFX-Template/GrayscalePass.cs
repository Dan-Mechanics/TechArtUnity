using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
using static UnityEngine.Rendering.RenderGraphModule.Util.RenderGraphUtils;

public class GrayscalePass : ScriptableRenderPass
{
    Material material;
    RenderGraphUtils.BlitMaterialParameters blitParameters;
    RTHandle prevFrameTarget;

    public GrayscalePass()
    {
        material = new Material(Shader.Find("Custom/PostProcess/Grayscale"));
        renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        // Get Data
        var resourceData = frameData.Get<UniversalResourceData>();
        var cam = frameData.Get<UniversalCameraData>();

        // Skip for anything but game camera
        if (!cam.isGameCamera) return;

        // The following line ensures that the render pass doesn't blit
        // from the back buffer.
        if (resourceData.isActiveTargetBackBuffer)
            return;

        // Access active post-fx volume
        var stack = VolumeManager.instance.stack;
        var volume = stack.GetComponent<GrayscaleVolume>();
        if (!volume.IsActive()) return;

        // Set material float from active volume
        material.SetFloat("_Intensity", volume.intensity.value);

        // Create Handles
        TextureHandle srcCamColor = resourceData.activeColorTexture;
        var desc = cam.cameraTargetDescriptor;
        desc.depthBufferBits = 0;
        TextureHandle dst = UniversalRenderer.CreateRenderGraphTexture(renderGraph,
            desc, "Grayscale_Target", false);

        if (!srcCamColor.IsValid() || !dst.IsValid())
        {
            Debug.LogError("Invalid Source");
            return;
        }

        // Renders the active color texture with grayscale into the temporary render texture
        RenderGraphUtils.BlitMaterialParameters grayscale = new(srcCamColor, dst, material, 0);
        renderGraph.AddBlitPass(grayscale, "Grayscale Apply");

        // Copies the render texture back into the active color texture
        RenderGraphUtils.BlitMaterialParameters copyBack = new(dst, srcCamColor, material, 1);
        renderGraph.AddBlitPass(copyBack, "Grayscale CopyBack");
    }
}

[System.Serializable, VolumeComponentMenu("Custom/Grayscale")]
public class GrayscaleVolume : VolumeComponent, IPostProcessComponent
{
    public ClampedFloatParameter intensity = new(0f, 0f, 1f);

    public bool IsActive() => intensity.value > 0f;
    public bool IsTileCompatible() => false;
}