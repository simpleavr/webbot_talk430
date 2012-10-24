#!/usr/bin/perl -w
use strict;

my $readme =<<__README;

this is a perl script to convert the webbotlib speech sythesizer code from avr
to msp430 usage. this script is use at your own risk giftware. webbotlib has
it's own license terms.

. locate "webbotlib" and download version 2.x, i tried w/ webbotavrclib-1.35
. inside the package locate and extract the Audio/Text2Speech directory
. u will see the following files

Text2Speech.h
phoneme2sound.c
phonemeWriter.c
sound2noise.c
speech2phoneme.c
speechWriter.c
vocab_en.c

. place these files in a same directory as this (zconv.pl) script
. run it again and this script will
  . extract what's needed, ignore others
  . combine into a tighter package name "../webbot_speech.h"
  . replace avr controls w/ msp430 controls
. to use it in your firmware, do
  . include "webbot_speech.h"
  . say("Hello World");
  . enjoy :) and thanks webbot

2012.10.24 change log

. webbot_lib.h now reside in same directory
. now uses webbotlib package 2.x versions
. now compiles under CCS
. adopt to new mspgcc
  . mspgcc-20120406-p20120502
  . use of #include <legacymsp430.h>
  . retire own intrinsic __delay_cycle(), now uses mspgcc's
  . adopt to newer interrupt naming convention

<<< IMPORTANT >>>
please observe the fact that webbotlib is GPL licensed and use / share accordingly

__README

-f "vocab_en.c" or do {
	print $readme;
	exit;

};



my %hFuncs = ();

#______ list of functions to be replaced, mainly mapping pwm ports from avr to msp430
$hFuncs{speechInit} = "void speechInit() {";
 
$hFuncs{sound} = <<__END_sound;

#define PWM_TOP 0x400
static const int16_t Volume[16] = {
		0, PWM_TOP * 0.035, 
		PWM_TOP * 0.07, PWM_TOP * 0.105, 
		PWM_TOP * 0.14, PWM_TOP * 0.175, 
		PWM_TOP * 0.21, PWM_TOP * 0.25,
		PWM_TOP * 0.29, PWM_TOP * 0.325, 
		PWM_TOP * 0.36, PWM_TOP * 0.395, 
		PWM_TOP * 0.43, PWM_TOP * 0.465, 
		PWM_TOP * 0.5, PWM_TOP * 0.5, };


void sound(uint8_t b) {
	b = (b & 15);

	// Update PWM volume 
	int16_t duty = Volume[b];	  // get duty cycle	
	if (duty != CCR1) {
		TAR = 0;
		CCR1 = duty;
	}//if

__END_sound

$hFuncs{soundOff} = <<__END_soundOff;
void soundOff(void) {
	CCTL0 &= ~CCIE;
	P2DIR &= ~BIT6;
__END_soundOff


$hFuncs{soundOn} = <<__END_soundOn;
void soundOn(void) {
	CCTL0 &= ~CCIE;
	CCTL1 = OUTMOD_7;
	CCR0 = 0x200;							// more like 16Khz (16Mhz/1024)
	CCR1 = 0x00;
	TACTL = TASSEL_2 + MC_1;

	P2SEL |= BIT6;
	P2DIR |= BIT6;
	
	// initialise random number seed
	seed[0]=0xecu;
	seed[1]=7;
	seed[2]=0xcfu;
__END_soundOn

#______ we are going to call the ouput package webbot_speech.h

open O, "> webbot_speech.h" or die;

#______ say() and speak() were the very old api (pre-webbotlib)
print O <<__END_HEAD;
/*
if u are reading this, u had successfully converted the webbot speech code
to msp430 via a "zconv.pl" script
my other works can be found at www.simpleavr.com

webbotlib was created by webbot, details at webbot.org.uk

$readme
*/
#include <string.h>

#define say(x)		sayText(x)
#define speak(x)	sayPhonemes(x)

#define MIN(x,y)	((x>y) ? y : x)

__END_HEAD

my %hDupl = ();

#______ we will scan the following source file and migrate them to msp430
for my $ifile (qw/vocab_en.c sound2noise.c phoneme2sound.c speech2phoneme.c/) {
	open I, "<$ifile" or die;

	my ($func_skip, $skip, $func) = (0, 0, ());
	my $repl = 0;

	while (<I>) {
		chomp;
		s///g;
		#____ don't care for compiler switches, skip windows build and logging version
		/#if/ && /_LOG_/ and $skip = 1;
		/#else/ and $skip = $skip ? 0 : 1;
		/#endif/ and $skip = 0;

		/#(if|else|endif)/ and next;

		#____ can't use avr stuffs
		/Text2Speech.h/ and next;
		/timer.h/ and next;
		/TimerCompare/ and next;
		/pwmPin/ and next;
		/rprintf\.h/ and next;
		/static uint16_t Volume\[16\];/ and next;

		#____ convert general avr stuffs to msp430 equivalents
		s/boolean/uint8_t/;
		s/null/NULL/;
		s/IOPin/uint/;
		s/_delay_loop_1/__delay_cycles/;
		s/pause\(0\)/pause(255)/;
		s/pgm_read_byte\(&([^\)]+)\)/$1/;
		s/rprintfChar\((\w+)\);/*pText++ = $1;/;

		#____ nor infrastructural stuffs from webbot
		/rprintf/ and next;
		/Writer/ and next;
		/logger/ and next;


		#____ need to place them in code segment, too big for ram
		s/(static\s+)(uint8_t\s+SoundData\[\])/$1const $2/;

		#____ init speech pause values, not used pre 2.0 version
		#s/(static\s+uint8_t\s+timeFactor)/$1 = 16/;
		/_speech_timeFactor;\s*$/ and next;
		s/=\s*_speech_timeFactor;/=16;/;

		#____ works better w/ CCS
		s/__inline__/__inline/;

		#____ change delay time to constant
		s/for\(r=16/for(r=delay/;
		s/__delay_cycles\(delay\)/__delay_cycles(16)/;

		#____ no need in msp430, it's automatic when we are "static const"
		s/PROGMEM\s*//;

		#____ identify functions and replace some, webbot's consistent code style helps a lot
		/^\S.*\s+([\w\d_]+)\(.*\)\s*\{/ and do {
			$func = $1;
			print "$func()\n";
			exists $hDupl{$func} and $hFuncs{$func} = "// duplicated function $func() removed {";
			exists $hFuncs{$func} and do {
				print O $hFuncs{$func};
				$func_skip = 1;
			};
			$hDupl{$func} = 1;
		};

		$func and /^\}\s*$/ and do { ($func_skip, $func) = (0, ()); };
		$skip || $func_skip and next;
		#____ some enrichments
		/^(\s*)static char sounds\[/ and
			print O "$1static char *pText, text[64];\n";
		/^(\s*)text2Phonemes\(src\);/ and
			$_ = "$1pText = text;\n$_\n$1*pText = '\\0';\n$1sayPhonemes((const char*) text);\n";
		print O "$_\n";
	}
	close I;
}
close O;


