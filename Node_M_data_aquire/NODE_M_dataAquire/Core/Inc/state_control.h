/* ========================================
 * state_control.h
 * =========================================
 */

#ifndef STATE_CONTROL_H_
#define STATE_CONTROL_H_

#include <stdint.h>

/* =========================================
 * SYSTEM STATES
 * =========================================
 */
typedef enum
{
	IDLE,
	DATA_AQUIRE,
	CHECK_CRC,
	PACKETNIZATION,
	SD_CARD_WRITE,
	SEND_ACK,
	SEND_NACK,
	FINISH
} SystemState_t;

/* =========================================
 * GLOBAL STATE
 * =========================================
 */
typedef struct
{
	volatile uint8_t INT_FLAG;
	volatile uint8_t RECEIVED_LEN;
	volatile uint8_t CRC_FALSE;
	volatile uint8_t CRC_TRUE;
	volatile uint8_t FINISH;
} SystemStateInput_t;

/* =========================================
 * API
 * =========================================
 */
void StateControl_Init(SystemState_t *state, SystemStateInput_t *system_input);
void StateControl_ChangeState(SystemState_t *system_state, SystemStateInput_t system_input);
#endif /* STATE_CONTROL_H_ */

