#pragma once

struct Spheres
{
	float* x_unrotated;
	float* y_unrotated;
	float* z_unrotated;
		
	float* x;
	float* y;
	float* z;

	float* radius;

	float* R;
	float* G;
	float* B;

	float* ka;
	float* kd;
	float* ks;
	float* alpha;
};

void h_allocate_memory_for_spheres(Spheres* spheres, int n);
void h_clean_memory_for_spheres(Spheres* spheres);
void d_allocate_memory_for_spheres(Spheres* spheres, int n);
void d_clean_memory_for_spheres(Spheres* spheres);
void create_random_spheres(Spheres* spheres, int n);
