using UnityEngine;

public class OrbitRotate : MonoBehaviour
{
    [Tooltip("绕着哪个物体旋转")]
    public Transform targetCenter;

    [Tooltip("旋转轴 Y轴=上下  X轴=左右  Z轴=前后")]
    public Vector3 rotateAxis = Vector3.up;

    [Tooltip("旋转速度，数值越大转得越快")]
    public float rotateSpeed = 50f;

    void Update()
    {
        // 核心代码：自身绕目标物体的位置、指定轴、按速度旋转
        transform.RotateAround(
            targetCenter.position,
            rotateAxis,
            rotateSpeed * Time.deltaTime
        );
    }
}