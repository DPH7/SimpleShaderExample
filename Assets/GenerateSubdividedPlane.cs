#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class GenerateSubdividedPlane
{
    // 在 Unity 顶部菜单栏添加一个快捷生成入口：GameObject -> 3D Object -> Subdivided Plane (20x20)
    [MenuItem("GameObject/3D Object/Subdivided Plane (20x20)", false, 10)]
    public static void CreatePlane()
    {
        int gridX = 50; // X 轴细分数
        int gridZ = 50; // Z 轴细分数
        float sizeX = 10f; // 宽度 (与 Unity 默认 Plane 尺寸 10x10 保持一致)
        float sizeZ = 10f; // 长度

        // 1. 生成网格
        Mesh mesh = GeneratePlaneMesh(gridX, gridZ, sizeX, sizeZ);

        // 2. 将生成的 Mesh 保存为 Assets 目录下的 Asset 文件，方便后续重复挂载
        string path = "Assets/Plane_50x50.mesh";
        string uniquePath = AssetDatabase.GenerateUniqueAssetPath(path);
        AssetDatabase.CreateAsset(mesh, uniquePath);
        AssetDatabase.SaveAssets();

        // 3. 在当前场景中自动创建一个带有该网格的 GameObject
        GameObject go = new GameObject("SubdividedPlane_50x50");
        MeshFilter mf = go.AddComponent<MeshFilter>();
        MeshRenderer mr = go.AddComponent<MeshRenderer>();
        mf.sharedMesh = mesh;

        // 赋予 Unity 默认材质
        mr.sharedMaterial = AssetDatabase.GetBuiltinExtraResource<Material>("Default-Material.mat");

        // 选中创建出的物体
        Selection.activeGameObject = go;
        Undo.RegisterCreatedObjectUndo(go, "Create Subdivided Plane");

        Debug.Log($"50x50 细分 Plane 生成成功！Mesh 文件已保存至: {uniquePath}");
    }

    private static Mesh GeneratePlaneMesh(int gridX, int gridZ, float width, float length)
    {
        Mesh mesh = new Mesh();
        mesh.name = "Plane_50x50";

        int vCountX = gridX + 1; // 21
        int vCountZ = gridZ + 1; // 21
        int totalVerts = vCountX * vCountZ; // 441 个顶点

        Vector3[] vertices = new Vector3[totalVerts];
        Vector2[] uvs = new Vector2[totalVerts];
        Vector4[] tangents = new Vector4[totalVerts];
        Vector4 tangent = new Vector4(1f, 0f, 0f, -1f);

        // 计算顶点坐标与 UV
        for (int z = 0; z < vCountZ; z++)
        {
            float zPos = ((float)z / gridZ - 0.5f) * length;
            float v = (float)z / gridZ;

            for (int x = 0; x < vCountX; x++)
            {
                float xPos = ((float)x / gridX - 0.5f) * width;
                float u = (float)x / gridX;

                int index = z * vCountX + x;
                vertices[index] = new Vector3(xPos, 0, zPos);
                uvs[index] = new Vector2(u, v);
                tangents[index] = tangent;
            }
        }

        // 计算三角形索引 (400 个小格子, 每个格子 2 个三角形, 共 800 个三角形)
        int totalQuads = gridX * gridZ;
        int[] triangles = new int[totalQuads * 6];
        int triIndex = 0;

        for (int z = 0; z < gridZ; z++)
        {
            for (int x = 0; x < gridX; x++)
            {
                int vertIndex = z * vCountX + x;

                // 第一三角形
                triangles[triIndex++] = vertIndex;
                triangles[triIndex++] = vertIndex + vCountX;
                triangles[triIndex++] = vertIndex + 1;

                // 第二三角形
                triangles[triIndex++] = vertIndex + 1;
                triangles[triIndex++] = vertIndex + vCountX;
                triangles[triIndex++] = vertIndex + vCountX + 1;
            }
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.tangents = tangents;

        // 自动计算法线与包围盒
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        return mesh;
    }
}
#endif