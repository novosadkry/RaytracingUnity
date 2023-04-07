using System.Linq;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;

[ExecuteAlways, ImageEffectAllowedInSceneView]
public class ShaderDispatch : MonoBehaviour
{
    private static readonly int NearClipParamsID = Shader.PropertyToID("NearClipParams");
    private static readonly int ScreenParamsID = Shader.PropertyToID("ScreenParams");
    private static readonly int CamLocalToWorldMatrixID = Shader.PropertyToID("CamLocalToWorldMatrix");
    private static readonly int MaxBounceID = Shader.PropertyToID("MaxBounce");
    private static readonly int RaysPerPixelID = Shader.PropertyToID("RaysPerPixel");
    private static readonly int SpheresID = Shader.PropertyToID("Spheres");
    private static readonly int SpheresCountID = Shader.PropertyToID("SpheresCount");
    private static readonly int OldRenderID = Shader.PropertyToID("_OldRender");
    private static readonly int FrameIndexID = Shader.PropertyToID("FrameIndex");

    public Shader rayShader;
    public Shader accuShader;
    public bool renderInSceneView;
    public int maxBounce;
    public int raysPerPixel;
    public List<SphereObject> spheres;

    [SerializeField] private int framesRendered;
    private Material _rayMaterial;
    private Material _accuMaterial;
    private RenderTexture _oldRenderTexture;
    private RenderTexture _newRenderTexture;
    private RenderTexture _accumulationTexture;
    private ComputeBuffer _spheresBuffer;

    private void OnEnable()
    {
        framesRendered = 0;
        var rt = RenderTexture.active;
        RenderTexture.active = _oldRenderTexture;
        GL.Clear(true, true, Color.clear);
        RenderTexture.active = rt;
    }

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        var cam = Camera.current;
        if (cam.name != "SceneCamera" || renderInSceneView)
        {
            InitRenderTexture(cam, ref _oldRenderTexture);
            InitRenderTexture(cam, ref _newRenderTexture);
            InitRenderTexture(cam, ref _accumulationTexture);
            UpdateParameters(cam);

            Graphics.Blit(null, _newRenderTexture, _rayMaterial);
            Graphics.Blit(_newRenderTexture, _accumulationTexture, _accuMaterial);
            Graphics.Blit(_accumulationTexture, _oldRenderTexture);
            Graphics.Blit(_accumulationTexture, dest);

            framesRendered++;
        }

        else
            Graphics.Blit(src, dest);
    }

    private void UpdateParameters(Camera cam)
    {
        float halfFov = cam.fieldOfView * Mathf.Deg2Rad * 0.5f;
        float height = cam.nearClipPlane * Mathf.Tan(halfFov) * 2;
        float width = cam.aspect * height;

        _rayMaterial.SetVector(NearClipParamsID, new Vector3(width, height, cam.nearClipPlane));
        _rayMaterial.SetVector(ScreenParamsID, new Vector2(cam.pixelWidth, cam.pixelHeight));
        _rayMaterial.SetMatrix(CamLocalToWorldMatrixID, cam.transform.localToWorldMatrix);
        _rayMaterial.SetInteger(MaxBounceID, maxBounce);
        _rayMaterial.SetInteger(RaysPerPixelID, raysPerPixel);
        _rayMaterial.SetInteger(SpheresCountID, spheres.Count);
        _rayMaterial.SetInteger(FrameIndexID, framesRendered);
        _rayMaterial.SetBuffer(SpheresID, _spheresBuffer);

        _accuMaterial.SetTexture(OldRenderID, _oldRenderTexture);
        _accuMaterial.SetInteger(FrameIndexID, framesRendered);
    }

    private void OnValidate()
    {
        InitMaterial(rayShader, ref _rayMaterial);
        InitMaterial(accuShader, ref _accuMaterial);
        InitBuffer(spheres.Select(x => x.sphere).ToList(), ref _spheresBuffer);
    }

    private void InitBuffer<T>(List<T> list, ref ComputeBuffer buffer) where T : struct
    {
        if (list is { Count: > 0 })
        {
            buffer?.Release();
            buffer = new ComputeBuffer(list.Count, Marshal.SizeOf(typeof(T)), ComputeBufferType.Structured);
            buffer.SetData(list);
        }
    }

    private void InitRenderTexture(Camera cam, ref RenderTexture rt)
    {
        if (rt == null || cam.pixelWidth != rt.width || cam.pixelHeight != rt.height)
        {
            rt?.Release();
            rt = new RenderTexture(cam.pixelWidth, cam.pixelHeight, 0);
        }
    }

    private void InitMaterial(Shader shader, ref Material material)
    {
        DestroyImmediate(material);

        if (shader != null)
            material = new Material(shader);
    }
}
