using System;
using UnityEngine;
using System.IO;

public class NoiseGenerator : MonoBehaviour
{
    public int width = 512;
    public int height = 512;
    public float scale = 10f;

    private void Start()
    {
        GenerateTexture();
    }

    void GenerateTexture()
    {
        Texture2D texture = new Texture2D(width, height);

        for (int x = 0; x < width; x++)
        {
            for (int y = 0; y < height; y++)
            {
                float xCoord = (float)x / width * scale;
                float yCoord = (float)y / height * scale;
                float sample = Mathf.PerlinNoise(xCoord, yCoord);
                texture.SetPixel(x, y, new Color(sample, sample, sample));
            }
        }
        texture.Apply();

        // 保存为 PNG
        byte[] bytes = texture.EncodeToPNG();
        File.WriteAllBytes(Application.dataPath + "/GeneratedNoise.png", bytes);
        Debug.Log("噪波贴图生成完毕！路径: Assets/GeneratedNoise.png");
    }
}