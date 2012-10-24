#include <msp430.h>

#ifdef MSP430
	#include <legacymsp430.h>
#endif

#include <stdint.h>
#include <stdio.h>
//  November 2011
//  code provided as is, no warranty
//  October 2012
//  . adopt newer mspgcc
//  . new compiles under CCS
//
//
/*
                                                                         
               MSP430G2553         ----------+---------------       ----
             -----------------     |         |              |      /    \
         /|\|              XIN|-   |        ---             |      |    |
          | |                 |   .-.       --- 10-500nF    o      \    /
          --|RST          XOUT|-  | | 1-10K  |            Audio out o  o
            |                 |   |_|        |--------------o
      LED <-|P1.0             |    |        ___                               
            |                 |    |        ///    
            |    pwm out  P2.6|-----           
            |                 |
            |                 |
            |                 |

*/
#define MHZ     8

//#define G2231
//#define G2452 *** must use G2553, it won't fit on 8k devices
#define G2553


#include "common.h"
#include "uart.h"

#define TRUE	1
#define FALSE	0

#define FILE	int

#include "webbot_speech.h"

const char quick[] = "the quick brown fox jump over the lazy dog";
const char dave[] = "i am afraid i can't do that, dave";
const char luke[] = "luke, i am your father";
const char time[] = "the time is seven thirty five";
const char temp[] = "the temperature is six degree celsius";
//______________________________________________________________________
int main() {
	WDTCTL = WDTPW + WDTHOLD;
	__use_cal_clk(MHZ);

	P1SEL = 0;
	P1DIR = 0;
	P1OUT = 0;
	P2SEL = 0;
	P2DIR = 0;
	P2OUT = 0;

	_BIC_SR(GIE);

	led_init();
	led_off();

	uart_init();

	_BIS_SR(GIE);

	char buf[64], *at=buf;
	uint8_t c = 0;

	while (1) {
		if (c || uart_getc(&c)) {
			switch (c) {
				case '.': led_flip(); break;
				case '1': uart_puts(quick); uart_putc('\n'); say(quick); break;
				case '2': uart_puts(dave); uart_putc('\n'); say(dave); break;
				case '3': uart_puts(luke); uart_putc('\n'); say(luke); break;
				case '4': uart_puts(time); uart_putc('\n'); say(time); break;
				case '5': uart_puts(temp); uart_putc('\n'); say(temp); break;
				case '\r':	// end of command
					uart_putc('\n');
					*at = '\0';
					at = buf;
					if (*at == '*') {
						speak(at+1);
					}//if
					else {
						if (*at == '!')
							setPitch(*(at+1)-'A');
						else
							say(at);
					}//else
					uart_puts("\ndone\n");
					break;
				default:
					*at++ = c;
					uart_putc(c);
					break;
			}//switch
		}//if
		c = 0;
	}//while

}

//______________________________________________________________________
#ifdef MSP430
interrupt(TIMER0_A0_VECTOR) TIMER0_A0_ISR(void)
#else
#pragma vector=TIMER0_A0_VECTOR
__interrupt void TIMER0_A0_ISR(void)
#endif
{
	uart_timera0_isr();
}

//______________________________________________________________________
#ifdef MSP430
interrupt(PORT1_VECTOR) PORT1_ISR(void)
#else
#pragma vector=PORT1_VECTOR
__interrupt void PORT1_ISR(void)
#endif
{
	_BIC_SR(GIE);
	led_on();
	uart_port1_isr();
	P1IFG = 0x00;
	led_off();
	_BIS_SR(GIE);
}

