#pragma once
#include <torch/extension.h>
#include "../chess-attacks.cu"
#include "../chess-consts.h"


__device__ unsigned char queenside_castle(
    int env,
    torch::PackedTensorAccessor32<int , 1 , torch::RestrictPtrTraits> players ,
    torch::PackedTensorAccessor32<int , 2 , torch::RestrictPtrTraits> boards  ,
    torch::PackedTensorAccessor32<int , 2 , torch::RestrictPtrTraits> actions
) {
    // performs queenside castling action
    // returns 0 if everything is ok
    // returns 1 if the action was a queenside castling but the conditions were not met

    const unsigned char PLAYER_KING = players[env] * 6 + WHITE_KING;
    const unsigned char PLAYER_ROOK = players[env] * 6 + WHITE_ROOK;
    const unsigned char special = actions[env][4];
    const unsigned char king_source = (7 * players[env]) * 8 + 4;
    const unsigned char rook_target = (7 * players[env]) * 8 + 3;
    const unsigned char king_target = (7 * players[env]) * 8 + 2;
    const unsigned char rook_side   = (7 * players[env]) * 8 + 1;
    const unsigned char rook_source = (7 * players[env]) * 8 + 0;

    const bool is_queenside_castle =  (
        (actions[env][0] == 0    ) & // action source empty
        (actions[env][1] == 0    ) & // action source empty
        (actions[env][2] == 0    ) & // action target empty
        (actions[env][3] == 0    ) & // action target empty
        (special == QUEEN_CASTLE )   // queenside castling action
    );

    const bool is_action_ok = ( 
        (boards[env][KING_MOVED + players[env]] == 0              ) & // king has not moved
        (boards[env][QUEENSIDE_ROOK_MOVED + players[env]] == 0    ) & // queen-side rook has not moved
        (boards[env][king_source] == PLAYER_KING                  ) & // king is in the right position
        (boards[env][rook_target] == EMPTY                        ) & // rook-target is empty
        (boards[env][king_target] == EMPTY                        ) & // king-target is empty
        (boards[env][rook_side]   == EMPTY                        ) & // rook-side is empty
        (boards[env][rook_source] == PLAYER_ROOK                  ) & // rook is in the right position
        (count_attacks(env, king_source, 4, players, boards) == 0 ) & // king is not in check
        (count_attacks(env, king_target, 3, players, boards) == 0 ) & // king target is not in check
        (count_attacks(env, rook_target, 2, players, boards) == 0 )   // rook target is not in check
    );

    boards[env][rook_target] = (is_queenside_castle & is_action_ok) ? PLAYER_ROOK : boards[env][rook_target];
    boards[env][king_target] = (is_queenside_castle & is_action_ok) ? PLAYER_KING : boards[env][king_target];
    boards[env][king_source] = (is_queenside_castle & is_action_ok) ? EMPTY       : boards[env][king_source];
    boards[env][rook_side  ] = (is_queenside_castle & is_action_ok) ? EMPTY       : boards[env][rook_side  ];
    boards[env][rook_source] = (is_queenside_castle & is_action_ok) ? EMPTY       : boards[env][rook_source];

    return is_queenside_castle & (!is_action_ok);
}

__global__ void queenside_castle_kernel(
    torch::PackedTensorAccessor32<int , 2 , torch::RestrictPtrTraits> boards  ,
    torch::PackedTensorAccessor32<int , 2 , torch::RestrictPtrTraits> actions ,
    torch::PackedTensorAccessor32<int , 1 , torch::RestrictPtrTraits> players ,
    torch::PackedTensorAccessor32<int , 1 , torch::RestrictPtrTraits> result
) {
    const int env = clamp(0,boards.size(0)-1,blockIdx.x * blockDim.x + threadIdx.x);
    result[env] = queenside_castle(env, players, boards, actions);
}

