/* =========================================
 * state_control.c
 * =========================================
 */

#include "state_control.h"

/* =========================================
 * GLOBAL STATE
 * =========================================
 */


/* =========================================
 * INIT
 * =========================================
 */
void StateControl_Init(SystemState_t *state,
                       SystemStateInput_t *system_input)
{
    *state = IDLE;

    system_input->ecg_half_ready = 0;
    system_input->ecg_full_ready = 0;
    system_input->packet_ready   = 0;
    system_input->got_ACK        = 0;
    system_input->got_NACK       = 0;
}

/* =========================================
 * STATE MACHINE
 * =========================================
 */
void StateControl_ChangeState(SystemState_t *system_state,
                              SystemStateInput_t system_input)
{
    switch (*system_state)
    {
        case IDLE:
        {
            if (system_input.ecg_half_ready ||
                system_input.ecg_full_ready)
            {
                *system_state = BUFFER_READY;
            }
            break;
        }

        case BUFFER_READY:
        {
            if (system_input.packet_ready)
            {
                *system_state = PACKET_READY;
            }
            break;
        }

        case PACKET_READY:
        {
            *system_state = WAIT_ACK_NACK;
            break;
        }
        case WAIT_ACK_NACK:
        {
        	if(system_input.got_ACK)
        		*system_state = ACK;
        	else if(system_input.got_NACK)
        		*system_state = NACK;
        	break;
        }
        case ACK:
        {
        	*system_state = IDLE;
        	break;
        }
        case NACK:
        {
        	*system_state = IDLE;
        	break;
        }

        default:
        {
            *system_state = IDLE;
            break;
        }
    }
}
