#ifndef CAMERA_HELPERS
#define CAMERA_HELPERS

#include <cuda_runtime.h>
#include "../objects/light_sources.cuh"
#include "../objects/spheres.cuh"
#include "../external/cuda-samples/helper_math.h"

//extern __global__ rotate_spheres(Spheres spheres, )
extern float angle_to_rad(float angle);
extern float3 rotate_camera_y(int angle, float3 camera_pos);
extern void rotate_positions(float* x, float* z, float* x_unrot, float* z_unrot, float angle, int n);
#endif 