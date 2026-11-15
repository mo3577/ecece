//go:build windows && cgo

package main

// Prefer the discrete GPU on hybrid NVIDIA Optimus / AMD PowerXpress systems.
// The driver looks for these exported symbols in the EXE.
/*
unsigned long NvOptimusEnablement = 1;
int AmdPowerXpressRequestHighPerformance = 1;
*/
import "C"
