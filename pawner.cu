#include <torch/extension.h>
#include "chess-attacks.cu"
#include "chess-moves.cu"

torch::Tensor step(torch::Tensor boards, torch::Tensor actions, torch::Tensor players, torch::Tensor rewards, torch::Tensor dones) {
    // The sole purpose of this function is to check inputs shapes, and launch the kernel

    // assume boards shape is (N, 68)
    if (boards.dim()   != 2  ) throw std::invalid_argument("Boards tensor must be 3D, (N, 132)");
    if (boards.size(1) != 132) throw std::invalid_argument("First dimension must be 132, found " + std::to_string(boards.size(1)));

    // assume actions shape is (N, 4)
    if (actions.dim()   != 2) throw std::invalid_argument("Actions tensor must be 2D, (N, 4)");
    if (actions.size(1) != 4) throw std::invalid_argument("First dimension must be 4, found " + std::to_string(actions.size(1)));

    // assume players shape is (N)
    if (players.dim() != 1) throw std::invalid_argument("Players tensor must be 1D, (N)");

    // assume rewards shape is (N,2)
    if (rewards.dim() != 2) throw std::invalid_argument("Rewards tensor must be 2D, (N, 2)");
    if (rewards.size(1) != 2) throw std::invalid_argument("First dimension must be 2, found " + std::to_string(rewards.size(1)));

    // assume terminated shape is (N)
    if (dones.dim() != 1) throw std::invalid_argument("Dones tensor must be 1D, (N)");

    // zero-fill rewards and dones
    rewards.fill_(0);
    dones.fill_(false);

    // launch the necessary block made of 1024 threads
    int threads = 1024;
    int blocks = (boards.size(0) + threads - 1) / threads;
    step_kernel<<<blocks, threads>>>(
        boards    .packed_accessor64<long , 2, torch::RestrictPtrTraits>(),
        actions   .packed_accessor64<long , 2, torch::RestrictPtrTraits>(),
        players   .packed_accessor64<long , 1, torch::RestrictPtrTraits>(),
        rewards   .packed_accessor64<float, 2, torch::RestrictPtrTraits>(),
        dones     .packed_accessor64<bool , 1, torch::RestrictPtrTraits>()
    );

    return boards;
}



void attacks(torch::Tensor boards, torch::Tensor players, torch::Tensor colors) {
    // The sole purpose of this function is to make sanity cheks and launch the kernel

    // assume boards shape is (N, 68)
    TORCH_CHECK(boards.dim()   == 2 , "Boards tensor must be 3D, (N, 66)");
    TORCH_CHECK(boards.size(1) == 66, "First dimension must be 66, found " + std::to_string(boards.size(1)));

    // assume colors shape is (N, 64)
    TORCH_CHECK(colors.dim()   == 2 , "Colors tensor must be 2D, (N, 64)");
    TORCH_CHECK(colors.size(1) == 64, "First dimension must be 64, found " + std::to_string(colors.size(1)));

    // assume players shape is (N)
    TORCH_CHECK(players.dim() == 1, "Players tensor must be 1D, (N)");

    // all tensor mush be on gpu
    TORCH_CHECK(boards.is_cuda(), "boards must be a CUDA tensor");
    TORCH_CHECK(players.is_cuda(), "players must be a CUDA tensor");
    TORCH_CHECK(colors.is_cuda(), "colors must be a CUDA tensor");

    // launch a 64-threads-block for each board
    dim3 griddim(boards.size(0));
    dim3 blockdim(8, 8);
    attacks_kernel<<<griddim, blockdim>>>(
        boards    .packed_accessor64<long , 2, torch::RestrictPtrTraits>(),
        players   .packed_accessor64<long , 1, torch::RestrictPtrTraits>(),
        colors    .packed_accessor64<long , 2, torch::RestrictPtrTraits>()
    );
    cudaDeviceSynchronize();

    // check errors
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) throw std::runtime_error(cudaGetErrorString(err));
}

// macro to create the python binding
PYBIND11_MODULE(TORCH_EXTENSION_NAME, python_module) {
    //python_module.def("step", &step, "In-place Step function");
    python_module.def("attacks", &attacks, "Color function");
}