#ifndef _TIMER_H_
#define _TIMER_H_

#define TIMER0_BASE   (0x20000000)
#define TIMER0_CTRL   (TIMER0_BASE + (0x00))
#define TIMER0_COUNT  (TIMER0_BASE + (0x04))
#define TIMER0_VALUE  (TIMER0_BASE + (0x08))

// Add by YanZY, 202501021845. Reference from TASK1
#define TIMER0_I  (TIMER0_BASE + (12))
#define TIMER0_SUM_RESULT  (TIMER0_BASE + (16))
#define TIMER0_SUM_CTRL  (TIMER0_BASE + (20))
#define TIMER0_I_VALUE  (TIMER0_BASE + (24))

#define TIMER0_REG(addr) (*((volatile uint32_t *)addr))

#endif
