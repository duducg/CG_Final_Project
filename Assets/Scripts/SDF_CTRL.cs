using NaughtyAttributes;
using UnityEngine;

[ExecuteInEditMode]
public class SDF_CTRL : MonoBehaviour
{
    [SerializeField] private MeshRenderer _ms;    
    [SerializeField] private string _targetVectorField;    
    private Material _rayMarcher;    
    private Vector4 _sphere;

    // [Header("Reflection")]
    // [Range(0, 2)]
    // [SerializeField] private int _reflectionCount;
    // [Range(0, 1)]
    // [SerializeField] private float _reflectionIntensity;
    // [Range(0, 1)]
    // [SerializeField] private float _envRefLIntensity;
    // [SerializeField] private Cubemap _reflectionCube;

    [Button]
    public void RebindMaterial()
    {
        _rayMarcher = _ms.GetComponent<Renderer>().material;
        //This later needs to be moved to onrenderimage so it doenst update every single frame
    }
    
    private void Awake()
    {
        _rayMarcher = _ms.GetComponent<Renderer>().material;
        //This later needs to be moved to onrenderimage so it doenst update every single frame
    }
    void Update()
    {
        _sphere = new Vector4(transform.position.x,
        transform.position.y,
        transform.position.z,
        transform.localScale.x);
        _rayMarcher.SetVector(_targetVectorField, _sphere);
        // _rayMarcher.SetInt("_ReflectionCount", _reflectionCount);
        // _rayMarcher.SetFloat("_ReflectionIntensity", _reflectionIntensity);
        // _rayMarcher.SetFloat("_EnvRefLIntensity", _envRefLIntensity);
        // _rayMarcher.SetTexture("_ReflectionCube", _reflectionCube);
    }
        
        
        
       


  
}
