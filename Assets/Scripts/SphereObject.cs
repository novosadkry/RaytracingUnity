using System;
using UnityEngine;

[Serializable]
public struct Sphere
{
    public Vector3 position;
    public float radius;
    public RayMaterial material;
}

public class SphereObject : MonoBehaviour
{
    public Sphere sphere;

    public void Start()
    {
        throw new NotImplementedException();
    }
}
