using NaughtyAttributes;
using UnityEngine;

[ExecuteInEditMode]
public class LightCTRL : MonoBehaviour
{
    [SerializeField] private MeshRenderer _ms; 
    [SerializeField][Range(0, 7)] private int _lightIndex; //Does nothiong for now  
    [SerializeField] private string _lightName = "_LightPos";
    [SerializeField] private Color _lightColour = Color.white;   
    private Material _rayMarcher;    
    private Vector4 _light;    

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
        _light = new Vector4(transform.position.x,
        transform.position.y,
        transform.position.z,
        transform.localScale.x);
        _rayMarcher.SetVector(_lightName, _light);
        _rayMarcher.SetColor("_LightCol", _lightColour);

    }
}
