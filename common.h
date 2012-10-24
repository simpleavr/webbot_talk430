
#ifndef __COMMON_H

#define __COMMON_H

#include "stdarg.h"

#define ___use_cal_clk(x)	\
BCSCTL1 = CALBC1_##x##MHZ;	\
DCOCTL  = CALDCO_##x##MHZ;

#define __use_cal_clk(x)	___use_cal_clk(x)

#define FCPU    MHZ*1000000
#define USEC    MHZ

#define led_init_both()	P1DIR |= BIT0|BIT6
#define led_off_both()	P1OUT &= ~(BIT0|BIT6)
#define led_init()		P1DIR |= BIT0
#define led_off()       P1OUT &= ~BIT0
#define led_on()        P1OUT |= BIT0
#define led_flip()      P1OUT ^= BIT0

#define green_off()     P1OUT &= ~BIT6
#define green_on()      P1OUT |= BIT6

#define __blink_debug(x)	\
		do {	\
			int i;	\
			led_on(); for (i=0;i<100;i++) __delay_cycles(1000*USEC);	\
			led_off(); for (i=0;i<100;i++) __delay_cycles(1000*USEC);	\
		} while (x)

#ifdef G2231
#include <msp430g2231.h>
#endif
#ifdef G2452
#include <msp430g2452.h>
#endif
#ifdef G2553
#include <msp430g2553.h>
#endif


#define TASSEL__ACLK	TASSEL_1
#define TASSEL__SMCLK	TASSEL_2
#define MC__UP			MC_1 

#endif
