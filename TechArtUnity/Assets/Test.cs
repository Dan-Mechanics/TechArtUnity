using UnityEngine;

public class Test : MonoBehaviour
{
    public Color color;

    private void FixedUpdate()
    {
        // STATIC.
        Shader.SetGlobalColor("_BaseColor", color);
    }
}
