#!/bin/bash

do_echo()
{
  cmd="$1"
  cmd_sub=$(eval echo $cmd)
  echo $cmd_sub
  eval $cmd_sub
}
