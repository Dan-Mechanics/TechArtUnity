using UnityEngine;

namespace TechArtUnity
{
    [ExecuteInEditMode]
    public class WorldLightingColors : MonoBehaviour
    {
        [SerializeField] private Camera cam = default;
        [SerializeField] private Color sunColor = Color.white;
        [SerializeField] private Color skyColor = Color.blue;
        [SerializeField, Range(0f, 1f)] private float shadingThreshold = 0.5f;
        [SerializeField, Range(-1f, 1f)] private float diffuseBias = default;

        private void Update()
        {
            if(cam != null)
                cam.backgroundColor = skyColor;

            RenderSettings.fogColor = skyColor;
            Shader.SetGlobalColor("_SunColor", sunColor);
            Shader.SetGlobalColor("_SkyColor", skyColor);
            Shader.SetGlobalFloat("_ShadingThreshold", shadingThreshold);
            Shader.SetGlobalFloat("_DiffuseBias", diffuseBias);
        }
    }
}