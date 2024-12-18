#include "renderers_helper.cuh"
#include <stdlib.h>



__device__ HitObj find_intersection_gpu_ver3(int ray_x, int ray_y, Spheres spheres, unsigned char* array, int n, float3 camera_pos, int num)
{
	HitObj res;
	res.x = 0;
	res.y = 0;
	res.z = FLT_MAX;
	res.index = -1;
	float radius;
	float3 A = make_float3(ray_x, ray_y, 0);
	float3 B = cuda_examples::normalize(A - camera_pos);
	float3 C;
	float b;
	float c;
	float d;
	int i = 0;
	while (i < n && !array[i])
		i++;
	for (; i < n;)
	{
		C = make_float3(spheres.x[i], spheres.y[i], spheres.z[i]);
		radius = spheres.radius[i];
		float3 A_C = A - C;
		b = 2 * cuda_examples::dot(B, A_C);
		float tmp = cuda_examples::dot(A_C, A_C);
		c = cuda_examples::dot(A_C, A_C) - radius * radius;
		d = b * b - 4 * c;
		if (d >= 0)
		{
			float sqrt_d = sqrtf(d);
			float inv2 = 0.5f;
			float step1 = (-b - sqrt_d) * inv2;

			bool var_b = step1 >= 0 && step1 < res.z;
			res.z = var_b ? A.z + step1 * B.z : res.z;
			res.x = var_b ? A.x + step1 * B.x : res.x;
			res.y = var_b ? A.y + step1 * B.y : res.y;
			res.index = var_b ? i : res.index;		
		}
		i++;
		while (array[i] != 1 && i < n)
		{
			i++;
		}
	}
	return res;
}



HitObj find_intersection_cpu(float ray_x, float ray_y, Spheres spheres, int n, float3 camera_pos, std::vector<int> interesting_spheres_indices)
{
	HitObj res;
	res.x = 0;
	res.y = 0;
	res.z = FLT_MAX;
	res.index = -1;
	float radius;
	float3 A = make_float3(ray_x, ray_y, 0);
	float3 B = cuda_examples::normalize(A - camera_pos);
	float3 C;
	float b;
	float c;
	float d;
	int i = 0;
	// Only for spheres, that can be in this block
	// Only this part is different for cpu
	std::vector<int>::iterator it;
	for (it = interesting_spheres_indices.begin(); it != interesting_spheres_indices.end(); it++)
	{
		i = *it;
		C = make_float3(spheres.x[i], spheres.y[i], spheres.z[i]);
		radius = spheres.radius[i];
		float3 A_C = A - C;
		b = 2 * cuda_examples::dot(B, A_C);
		float tmp = cuda_examples::dot(A_C, A_C);
		c = cuda_examples::dot(A_C, A_C) - radius * radius;
		d = b * b - 4 * c;
		if (d >= 0)
		{
			float sqrt_d = sqrtf(d);
			float inv2 = 0.5f;
			float step1 = (-b - sqrt_d) * inv2;

			bool var_b = step1 >= 0 && step1 < res.z;
			res.z = var_b ? A.z + step1 * B.z : res.z;
			res.x = var_b ? A.x + step1 * B.x : res.x;
			res.y = var_b ? A.y + step1 * B.y : res.y;
			res.index = var_b ? i : res.index;
		}
	}
	return res;
}

__host__ __device__ float3 find_color_for_hit(HitObj hit, Spheres spheres, LightSources lights, int nl, int i, int j, float3 camera_pos)
{
	// If no sphere intersection is detected
	if (hit.index == -1)
		return make_float3(0, 0, 0);
	float3 observer_pos = camera_pos;

	float3 sphere_center = make_float3(spheres.x[hit.index], spheres.y[hit.index], spheres.z[hit.index]);
	float3 sphere_color = make_float3(spheres.R[hit.index], spheres.G[hit.index], spheres.B[hit.index]);
	float3 hit_pos = make_float3(hit.x, hit.y, hit.z);
	float3 N = cuda_examples::normalize(hit_pos - sphere_center);
	float3 V = cuda_examples::normalize(observer_pos - hit_pos);
	float3 light_pos = make_float3(0, 0, 0);
	float3 light_color;
	float3 L;

	float3 R;
	float LN_dot_prod;
	float RV_dot_prod;
	float kd = spheres.kd[hit.index];
	float ks = spheres.ks[hit.index];
	float alpha = spheres.alpha[hit.index];
	float3 color_of_pixel = make_float3(0, 0, 0);
	for (int k = 0; k < nl; k++)
	{
		light_pos = make_float3(lights.x[k], lights.y[k], lights.z[k]);
		light_color = make_float3(lights.R[k], lights.G[k], lights.B[k]);

		L = cuda_examples::normalize(light_pos - hit_pos);

		// Also here find R vector
		R = cuda_examples::normalize(2 * cuda_examples::dot(L, N) * N - L);

		LN_dot_prod = cuda_examples::dot(L, N);
		RV_dot_prod = cuda_examples::dot(R, V);
		LN_dot_prod = cuda_examples::clamp(LN_dot_prod, 0.0f, 1.0f);
		RV_dot_prod = cuda_examples::clamp(RV_dot_prod, 0.0f, 1.0f);

		color_of_pixel += kd * LN_dot_prod * sphere_color + ks * pow(RV_dot_prod, alpha) * light_color;
	}
	color_of_pixel += spheres.ka[hit.index] * sphere_color;
	color_of_pixel = cuda_examples::clamp(color_of_pixel, make_float3(0, 0, 0), make_float3(1, 1, 1));
	return color_of_pixel;
}




void check_if_sphere_is_visible_for_block_cpu(int x_min, int y_max, int x_max, int y_min, float x, float y, float z, float radius, int index, float3 camera_pos, std::vector<int>* interesting_spheres_indices)
{
	if (z + radius < 0)
	{
		return;
	}

	float dz = z - camera_pos.z;
	float cam = fabs(camera_pos.z);
	float x_min_rad = x - radius;
	float x_pl_rad = x + radius;
	float y_min_rad = y - radius;
	float y_pl_rad = y + radius;
	float dz_min_rad = dz - radius;
	float dz_pl_rad = dz + radius;

	float proj_x_min = x_min_rad < 0 ? x_min_rad * cam / dz_min_rad : x_min_rad * cam / dz_pl_rad;
	float proj_x_max = x_pl_rad < 0 ? x_pl_rad * cam / dz_pl_rad : x_pl_rad * cam / dz_min_rad;
	float proj_y_min = y_min_rad < 0 ? y_min_rad * cam / dz_min_rad : y_min_rad * cam / dz_pl_rad;
	float proj_y_max = y_pl_rad < 0 ? y_pl_rad * cam / dz_pl_rad : y_pl_rad * cam / dz_min_rad;

	bool x_overlap = !(proj_x_max <= x_min || proj_x_min >= x_max);
	bool y_overlap = !(proj_y_max <= y_min || proj_y_min >= y_max);

	bool x_containing = (proj_x_min <= x_min && proj_x_max >= x_max);
	bool y_containing = (proj_y_min <= y_min && proj_y_max >= y_max);

	if ((x_overlap && y_overlap) || (x_containing && y_overlap) ||
		(x_overlap && y_containing) || (x_containing && y_containing))
	{
		(*interesting_spheres_indices).push_back(index);
	}
}


__device__ void check_if_sphere_is_visible_for_block(int x_min, int y_max, int x_max, int y_min, float x, float y, float z, float radius,
	unsigned char* array, int index, float3 camera_pos)
{
	
	if (z + radius < 0) {
		array[index] = 0; // Not visible
		return;
	}

	// Compute perspective projection
	float dz = z - camera_pos.z; // Distance to the camera
	float cam = fabs(camera_pos.z);
	//cam = cam == 0 ? 1 : cam;
	float x_min_rad = x - radius;
	float x_pl_rad = x + radius;
	float y_min_rad = y - radius;
	float y_pl_rad = y + radius;
	float dz_min_rad = dz - radius;
	float dz_pl_rad = dz + radius;

	float proj_x_min = x_min_rad < 0 ? x_min_rad * cam / dz_min_rad : x_min_rad * cam / dz_pl_rad;
	float proj_x_max = x_pl_rad < 0 ? x_pl_rad * cam / dz_pl_rad : x_pl_rad * cam / dz_min_rad;
	float proj_y_min = y_min_rad < 0 ? y_min_rad * cam / dz_min_rad : y_min_rad * cam / dz_pl_rad;
	float proj_y_max = y_pl_rad < 0 ? y_pl_rad * cam / dz_pl_rad : y_pl_rad * cam / dz_min_rad;

	bool x_overlap = !(proj_x_max <= x_min || proj_x_min >= x_max);
	bool y_overlap = !(proj_y_max <= y_min || proj_y_min >= y_max);
	
	bool x_containing = (proj_x_min <= x_min && proj_x_max >= x_max);
	bool y_containing = (proj_y_min <= y_min && proj_y_max >= y_max);
	
	array[index] = (x_overlap && y_overlap) || (x_containing && y_overlap) ||
		(x_overlap && y_containing) || (x_containing && y_containing) ? 1 : 0;
	
}
