/******************************************************************************
 * 
 * Copyright (c) 2011-2012, Duane Merrill.  All rights reserved.
 * Copyright (c) 2011-2012, NVIDIA CORPORATION.  All rights reserved.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License. 
 * 
 ******************************************************************************/

/******************************************************************************
 * Pass policy specializations
 ******************************************************************************/

#pragma once

#include <cub/cub.cuh>

#include <back40/radix_sort/pass_policy.cuh>
#include <back40/radix_sort/upsweep/kernel_policy.cuh>
#include <back40/radix_sort/spine/kernel_policy.cuh>
#include <back40/radix_sort/downsweep/kernel_policy.cuh>

namespace back40 {
namespace radix_sort {

/**
 * Problem size enumerations
 */
enum ProblemSize
{
	LARGE_PROBLEM,		// > 32K elements
	SMALL_PROBLEM		// <= 32K elements
};


/**
 * Tuned pass policy specializations
 */
template <
	int 			TUNE_ARCH,
	typename 		ProblemInstance,
	ProblemSize 	PROBLEM_SIZE,
	int 			BITS_REMAINING,
	int 			CURRENT_BIT,
	int 			CURRENT_PASS>
struct TunedPassPolicy;


/**
 * SM20
 */
template <typename ProblemInstance, ProblemSize PROBLEM_SIZE, int BITS_REMAINING, int CURRENT_BIT, int CURRENT_PASS>
struct TunedPassPolicy<200, ProblemInstance, PROBLEM_SIZE, BITS_REMAINING, CURRENT_BIT, CURRENT_PASS>
{
	enum {
		TUNE_ARCH			= 200,
		KEYS_ONLY 			= util::Equals<typename ProblemInstance::ValueType, util::NullType>::VALUE,
		RADIX_BITS 			= CUB_MIN(BITS_REMAINING, ((BITS_REMAINING + 4) % 5 > 3) ? 5 : 4),
		SMEM_8BYTE_BANKS	= false,
		EARLY_EXIT 			= false,
		LARGE_DATA			= (sizeof(typename ProblemInstance::KeyType) > 4) || (sizeof(typename ProblemInstance::ValueType) > 4),
	};

	// Dispatch policy
	typedef DispatchPolicy <
		TUNE_ARCH,							// TUNE_ARCH
		RADIX_BITS,							// RADIX_BITS
		false, 								// UNIFORM_SMEM_ALLOCATION
		true> 								// UNIFORM_GRID_SIZE
			DispatchPolicy;

	// Upsweep kernel policy
	typedef upsweep::KernelPolicy<
		RADIX_BITS,							// RADIX_BITS
		CURRENT_BIT,						// CURRENT_BIT
		CURRENT_PASS,						// CURRENT_PASS
		8,									// MIN_CTA_OCCUPANCY
		7,									// LOG_THREADS
		(LARGE_DATA ? 1 : 2),				// LOG_LOAD_VEC_SIZE
		1,									// LOG_LOADS_PER_TILE
		cub::LOAD_NONE,						// LOAD_MODIFIER
		cub::STORE_NONE,					// STORE_MODIFIER
		SMEM_8BYTE_BANKS,					// SMEM_8BYTE_BANKS
		EARLY_EXIT>							// EARLY_EXIT
			UpsweepPolicy;

	// Spine-scan kernel policy
	typedef spine::KernelPolicy<
		8,									// LOG_THREADS
		2,									// LOG_LOAD_VEC_SIZE
		2,									// LOG_LOADS_PER_TILE
		cub::LOAD_NONE,						// LOAD_MODIFIER
		cub::STORE_NONE>					// STORE_MODIFIER
			SpinePolicy;

	// Downsweep kernel policy
	typedef typename util::If<
		(!LARGE_DATA),
		downsweep::KernelPolicy<
			RADIX_BITS,						// RADIX_BITS
			CURRENT_BIT,					// CURRENT_BIT
			CURRENT_PASS,					// CURRENT_PASS
			(KEYS_ONLY ? 4 : 2),			// MIN_CTA_OCCUPANCY
			(KEYS_ONLY ? 7 : 8),			// LOG_THREADS
			4,								// LOG_ELEMENTS_PER_TILE
			cub::LOAD_NONE,					// LOAD_MODIFIER
			cub::STORE_NONE,				// STORE_MODIFIER
			downsweep::SCATTER_TWO_PHASE,	// SCATTER_STRATEGY
			SMEM_8BYTE_BANKS,				// SMEM_8BYTE_BANKS
			EARLY_EXIT>,					// EARLY_EXIT
		downsweep::KernelPolicy<
			RADIX_BITS,						// RADIX_BITS
			CURRENT_BIT,					// CURRENT_BIT
			CURRENT_PASS,					// CURRENT_PASS
			2,								// MIN_CTA_OCCUPANCY
			8,								// LOG_THREADS
			3,								// LOG_ELEMENTS_PER_TILE
			cub::LOAD_NONE,					// LOAD_MODIFIER
			cub::STORE_NONE,				// STORE_MODIFIER
			downsweep::SCATTER_TWO_PHASE,	// SCATTER_STRATEGY
			SMEM_8BYTE_BANKS,				// SMEM_8BYTE_BANKS
			EARLY_EXIT> >::Type 			// EARLY_EXIT
				DownsweepPolicy;
};



} // namespace radix_sort
} // namespace back40

