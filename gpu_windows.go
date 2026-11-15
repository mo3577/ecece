//go:build windows && cgo

// Prefer the discrete GPU on hybrid NVIDIA Optimus / AMD PowerXpress systems.
// The driver looks for NvOptimusEnablement / AmdPowerXpressRequestHighPerformance
// exported from this EXE. Keep only C declarations in the import "C" preamble
// (Go // comments above import "C" are fed to gcc and break C89 builds).
package main

/*
unsigned long NvOptimusEnablement = 1;
int AmdPowerXpressRequestHighPerformance = 1;
*/
import "C"
