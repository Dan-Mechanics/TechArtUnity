using UnityEngine;
using UnityEngine.UI;

namespace TechArtUnity
{
    public class Saturation : MonoBehaviour
    {
        [Range(-1f, 1f)] private float lerpValue = default;
        [SerializeField] Image read = default;
        [SerializeField] Image write = default;

        private void FixedUpdate()
        {
            Color input = read.color;
            float channel = (input.r + input.g + input.b) / 3f;
            Color grayscale = new Color(channel, channel, channel, 1f);
            write.color = Color.LerpUnclamped(input, grayscale, lerpValue);
        }
    }
}
