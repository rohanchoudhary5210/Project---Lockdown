class_name AimAssistData
extends Resource

## Project: Lockdown - Aim Assist Data Resource
## Defines tuning values for target acquisition, friction, and magnetism.

## Maximum targeting range in meters (only targets within 25m)
@export var max_range: float = 25.0

## Outer cone half-angle from crosshair center for candidate acquisition (degrees)
@export var assist_cone_angle_deg: float = 14.0

## Inner cone half-angle from crosshair to enemy chest where friction engages (degrees)
@export var friction_angle_deg: float = 4.0

## Look speed multiplier when crosshair is within friction angle (~4°)
@export var friction_scale_low: float = 0.75
@export var friction_scale_high: float = 0.55

## Maximum magnetism rotation speed toward target chest (degrees per second)
@export var magnetism_speed_low_deg: float = 2.0
@export var magnetism_speed_high_deg: float = 5.0
