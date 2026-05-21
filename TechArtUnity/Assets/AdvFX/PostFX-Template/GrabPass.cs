using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;
using static UnityEngine.Rendering.RenderGraphModule.Util.RenderGraphUtils;

public class GrabPass : ScriptableRenderPass
{
    Material material;
    RTHandle prevFrameTarget;

    public GrabPass( RenderTexture target )
    {
        material = new Material(Shader.Find("Custom/PostProcess/GrabPass"));
        renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;

        if (target != null )
            prevFrameTarget = RTHandles.Alloc(target);

        Debug.Log("CREATED");
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        // Get Data
        var resourceData = frameData.Get<UniversalResourceData>();
        var cam = frameData.Get<UniversalCameraData>();

        // Skip for anything but game camera
        if (!cam.isGameCamera || prevFrameTarget == null ) return;

        // The following line ensures that the render pass doesn't blit
        // from the back buffer.
        if (resourceData.isActiveTargetBackBuffer)
            return;

        if ( material == null )
            material = new Material(Shader.Find("Custom/PostProcess/GrabPass"));

        // Create Texture Handles
        TextureHandle srcCamColor = resourceData.activeColorTexture;
        var desc = cam.cameraTargetDescriptor;
        desc.depthBufferBits = 0;
        TextureHandle tHandle = renderGraph.ImportTexture(prevFrameTarget);

        if (!srcCamColor.IsValid() || !tHandle.IsValid())
        {
            Debug.LogError("Invalid TextureHandle");
            return;
        }
        
        RenderGraphUtils.BlitMaterialParameters copy = new(srcCamColor, tHandle, material, 0);
        renderGraph.AddBlitPass(copy, "Store Previous Frame");
    }
}