# PsAcano
Powershell implementation of the Acano API

## Introduction
The Acano Server provides management access through an API exposed through HTTPS in the WebAdmin on the server. This API is thorughly documented at https://www.acano.com/publications/2013/08/Solution-API-Reference-R1.7.pdf

Knowledge of this document is assumed before use of this module.

## Installation

To import this module, unpack or clone the PsAcano folder and run

`Import-Module .\PsAcano.psd1`

in the folder in Powershell. To make it load automatically when PowerShell starts, unpack, clone or copy it in to one of the folders defined in 

`$env:PsModulePath`

## Use

To start a new session against an Acano server, use the `Open-AcanoSession` cmdlet. To see an example, run

`help New-AcanoSession -Examples`

To get a list of possible commands use

`Get-Command -Module PsAcano`

## Caveats

Currently this module only contains the GET commands from the API. POST, PUT and DELETE are on their way. There is also no error handling in it at the moment. Feel free to give feedback through issues 
