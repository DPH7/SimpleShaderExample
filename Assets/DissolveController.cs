using System;
using UnityEngine;

[RequireComponent(typeof(SpriteRenderer))]
public class DissolveController : MonoBehaviour
{
    [Header("消融参数设置")]
    public float dissolveDuration = 5f;
    
    private SpriteRenderer spriteRenderer;
    private MaterialPropertyBlock propBlock;
    private static readonly int DissolveAmountID = Shader.PropertyToID("_DissolveAmount");

    void Awake()
    {
        spriteRenderer = GetComponent<SpriteRenderer>();
        propBlock = new MaterialPropertyBlock();

    }

}