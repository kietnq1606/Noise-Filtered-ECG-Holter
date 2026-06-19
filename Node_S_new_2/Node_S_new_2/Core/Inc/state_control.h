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
   BUFFER_READY,
   PACKET_READY,
   WAIT_ACK_NACK,
   ACK,
   NACK,
} SystemState_t;

/* =========================================
 * GLOBAL STATE
 * =========================================
 */
typedef struct
{
	volatile uint8_t ecg_half_ready;
	volatile uint8_t ecg_full_ready;
	volatile uint8_t packet_ready;
	volatile uint8_t got_ACK;
	volatile uint8_t got_NACK;
} SystemStateInput_t;

/* =========================================
 * API
 * =========================================
 */
void StateControl_Init(SystemState_t *state, SystemStateInput_t *system_input);
void StateControl_ChangeState(SystemState_t *system_state, SystemStateInput_t system_input);
#endif /* STATE_CONTROL_H_ */

