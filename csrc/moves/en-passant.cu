#pragma once
#include <torch/extension.h>
#include "../chess-consts.h"

__device__ bool en_passant(
    int env,
    torch::PackedTensorAccessor32<int , 1 , torch::RestrictPtrTraits> players ,
    torch::PackedTensorAccessor32<int , 2 , torch::RestrictPtrTraits> boards  ,
    torch::PackedTensorAccessor32<int , 2 , torch::RestrictPtrTraits> actions
) {
    // performs en passant
    // returns 0 if the action was performed
    // returns 1 if the action was not applicable
    
    const unsigned char player_pawn = players[env] * 6 + WHITE_PAWN;
    const unsigned char source = actions[env][0] * 8 + actions[env][1];
    const unsigned char target = actions[env][2] * 8 + actions[env][3];
    const unsigned char prev_target = boards[env][PREV_ACTION+2] * 8 + boards[env][PREV_ACTION+3];
    const unsigned char enpassant_src_row = players[env] == WHITE ? 3 : 4;
    const unsigned char enpassant_tgt_row = players[env] == WHITE ? 2 : 5;

    const bool is_action_ok = (
        (actions[env][4] == 0                               ) & // no special action
        (actions[env][0] == enpassant_src_row               ) & // action source is in en passant row
        (actions[env][2] == enpassant_tgt_row               ) & // action target is in en passant row
        (abs(actions[env][1] - actions[env][3]) == 1        ) & // moving on side column
        (boards[env][source] == player_pawn                 ) & // moving a pawn
        (boards[env][PREV_ACTION+4] == DOUBLE_PAWN_PUSH     ) & // previous action was a double pawn push 
        (boards[env][PREV_ACTION+3] == actions[env][3]      ) & // previous action was a double pawn push to the same column
        (boards[env][target] == EMPTY                       )   // action target is empty
    );

    boards[env][target] = is_action_ok ? player_pawn : boards[env][target];
    boards[env][source] = is_action_ok ? EMPTY       : boards[env][source];
    boards[env][prev_target] = is_action_ok ? EMPTY : boards[env][prev_target];

    return !is_action_ok;
}

__global__ void en_passant_kernel(
    torch::PackedTensorAccessor32<int , 2 , torch::RestrictPtrTraits> boards  ,
    torch::PackedTensorAccessor32<int , 2 , torch::RestrictPtrTraits> actions ,
    torch::PackedTensorAccessor32<int , 1 , torch::RestrictPtrTraits> players ,
    torch::PackedTensorAccessor32<int , 1 , torch::RestrictPtrTraits> result
) {
    const int env = blockIdx.x * blockDim.x + threadIdx.x;
    if (env < boards.size(0)) result[env] = en_passant(env, players, boards, actions);
}


