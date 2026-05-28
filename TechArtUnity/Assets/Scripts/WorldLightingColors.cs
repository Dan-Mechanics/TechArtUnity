using UnityEngine;

namespace TechArtUnity
{
    [ExecuteInEditMode]
    public class WorldLightingColors : MonoBehaviour
    {
        [SerializeField] private Camera cam = default;
        [SerializeField] private Color sunColor = default;
        [SerializeField] private Color skyColor = default;

        private void Update()
        {
            cam.backgroundColor = skyColor;
            RenderSettings.fogColor = skyColor;
            Shader.SetGlobalColor("_SunColor", sunColor);
            Shader.SetGlobalColor("_SkyColor", skyColor);
        }
    }
}