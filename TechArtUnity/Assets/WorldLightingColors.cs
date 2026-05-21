using UnityEngine;

public class WorldLightingColors : MonoBehaviour
{
    [SerializeField] private Camera cam = default;
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
        cam.backgroundColor = ambientColor;
        RenderSettings.fogColor = ambientColor;
    }

    public static Color GetSunColor() => sunColor;
    public static Color GetAmbientColor() => ambientColor;
}
