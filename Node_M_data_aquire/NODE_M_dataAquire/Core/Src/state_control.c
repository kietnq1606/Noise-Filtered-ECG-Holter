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

    system_input->INT_FLAG= 0;
    system_input->RECEIVED_LEN = 0;
    system_input->CRC_FALSE = 0;
    system_input->CRC_TRUE = 0;
    system_input->FINISH = 0;
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
            if(system_input.INT_FLAG)
            	*system_state  =  DATA_AQUIRE;
        	break;
        }

        case DATA_AQUIRE:
        {
        	if(system_input.RECEIVED_LEN == 118)
        		*system_state = CHECK_CRC;
            break;
        }

        case CHECK_CRC:
        {
            if(system_input.CRC_FALSE)
            	*system_state = SEND_NACK;
            else if(system_input.CRC_TRUE)
            	*system_state = SEND_ACK;
        	break;
        }
        case SEND_ACK:
        {
        	*system_state = PACKETNIZATION;
        	break;
        }
        case SEND_NACK:
        {
        	*system_state = IDLE;
        	break;
        }
        case PACKETNIZATION:
        {
        	*system_state = SD_CARD_WRITE;
        	break;
        }
        case SD_CARD_WRITE:
        {
        	if(system_input.FINISH)
        		*system_state = FINISH;
        	else
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
