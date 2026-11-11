//go:build windows && cgo

package main

/*
Force hybrid-GPU laptops/desktops to prefer the discrete adapter for this
process (NVIDIA Optimus / AMD PowerXpress). Windows and the driver look for
these exported symbols in the EXE.

unsigned long NvOptimusEnablement = 1;
int AmdPowerXpressRequestHighPerformance = 1;
*/
import "C"
