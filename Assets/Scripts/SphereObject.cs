using System;
using UnityEngine;

[Serializable]
public struct Sphere
{
    public Vector3 position;
    public float radius;
    public RayMaterial material;
}

[ExecuteAlways]
public class SphereObject : MonoBehaviour
{
    public Sphere sphere;

    public void Update()
    {
        sphere.position = transform.position;
        sphere.radius = transform.localScale.x * 0.5f;
    }

    private void OnDrawGizmosSelected()
    {
        Gizmos.color = sphere.material.color;
        Gizmos.DrawWireSphere(sphere.position, sphere.radius);
    }
}
