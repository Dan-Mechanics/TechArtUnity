using System.Collections.Generic;
using UnityEngine;

public class WorldLightingColors : MonoBehaviour
{
    [SerializeField] private bool debugMode = default;
    [SerializeField] private Color tempSunColor = Color.white;
    [SerializeField] private Color tempAmbientColor = Color.white;
    [SerializeField] private Camera cam = default;
    [SerializeField] private List<Material> materials = default;
    private static Color sunColor;
    private static Color ambientColor;

    public static void SetSunColor(Color color)
    {
        color.a = 1f;
        sunColor = color;
    }

    public static void SetAmbientColor(Color color)
    {
        color.a = 1f;
        ambientColor = color;
    }

    private void FixedUpdate()
    {
        if (debugMode)
        {
            SetSunColor(tempSunColor);
            SetAmbientColor(tempAmbientColor);
        }

        cam.backgroundColor = ambientColor;
        RenderSettings.fogColor = ambientColor;
        materials.ForEach(x => x.SetColor("_SunColor", sunColor));
        materials.ForEach(x => x.SetColor("_AmbientColor", ambientColor));
    }
}
