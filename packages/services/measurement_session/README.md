# Measurement Session Service

This package provides the client-side implementation of the synchronized acoustic measurement protocol.

## Features

- Measurement session coordination with the backend
- Audio playback for speaker role
- Audio recording for microphone role  
- State management for measurement phases
- Event handling for sync protocol

## Usage

The `MeasurementSessionBloc` coordinates with the backend to:

1. Create measurement sessions
2. Handle prepare/ready/start/finish events
3. Play measurement audio (speaker role)
4. Record measurement audio (microphone role)
5. Upload recordings to the server

## Protocol

See the backend documentation for the full synchronization protocol.
