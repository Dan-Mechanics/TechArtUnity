using UnityEngine;

namespace TechArtUnity
{
    public class Rotator : MonoBehaviour
    {
        [SerializeField] private Vector3 rotation = default;

        private void FixedUpdate()
        {
            transform.Rotate(rotation * Time.fixedDeltaTime, Space.Self);
        }
    }
}
