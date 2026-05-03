extends Node3D

# Procedural decoration spawner — pool-table-on-apartment vibe.
# 270 toy items densely scattered: 120 inside the 2 oval interiors + 150 exterior to the figure-8.
# Wrapped in StaticBody3D + BoxShape3D collision (auto-sized from mesh AABB) — non-traversable.
# Nothing on the racing line. Scale ×12 — boxes are the "right size" reference.

const TOY_BANANA := "res://assets/toy_kit/item-banana.glb"
const TOY_COIN_GOLD := "res://assets/toy_kit/item-coin-gold.glb"
const TOY_COIN_SILVER := "res://assets/toy_kit/item-coin-silver.glb"
const TOY_CONE := "res://assets/toy_kit/item-cone.glb"
const TOY_BOX := "res://assets/toy_kit/item-box.glb"

const FOOD_GLBS: Array = [
	"res://assets/food_kit/donut-sprinkles.glb",
	"res://assets/food_kit/sandwich.glb",
	"res://assets/food_kit/cake-birthday.glb",
	"res://assets/food_kit/pizza.glb",
	"res://assets/food_kit/cookie-chocolate.glb",
	"res://assets/food_kit/apple.glb",
]

const FLAG_GLB := "res://assets/track_pieces/flagCheckers.glb"
const PYLON_GLB := "res://assets/track_pieces/pylon.glb"

const SCALE_TOY := 12.0
const SCALE_FOOD := 14.0
const SCALE_FLAG := 18.0
const SCALE_PYLON := 10.0

const TOY_MAP := {
	"box": TOY_BOX,
	"banana": TOY_BANANA,
	"coin-gold": TOY_COIN_GOLD,
	"coin-silver": TOY_COIN_SILVER,
	"cone": TOY_CONE,
}

# 120 interior + 150 exterior = 270 toy items
var ALL_ITEMS: Array = [
	["box", Vector3(-7.90, 0.0, -54.74), 1.4025],
	["cone", Vector3(-5.45, 0.0, -81.97), 0.5463],
	["box", Vector3(-11.88, 0.0, -46.83), 3.1752],
	["coin-silver", Vector3(34.30, 0.0, -47.11), 3.4240],
	["coin-silver", Vector3(11.06, 0.0, -20.58), 0.0408],
	["banana", Vector3(22.39, 0.0, -80.60), 0.9769],
	["box", Vector3(43.63, 0.0, -56.01), 0.6077],
	["coin-silver", Vector3(34.85, 0.0, -74.79), 4.5850],
	["banana", Vector3(-74.96, 0.0, -58.68), 3.4686],
	["cone", Vector3(29.35, 0.0, -76.93), 3.6276],
	["box", Vector3(-4.70, 0.0, -58.01), 1.8183],
	["box", Vector3(33.00, 0.0, -40.96), 1.7466],
	["banana", Vector3(-31.00, 0.0, -67.74), 1.3164],
	["coin-silver", Vector3(-8.04, 0.0, -12.47), 3.8273],
	["box", Vector3(31.67, 0.0, -20.70), 2.3842],
	["coin-gold", Vector3(62.26, 0.0, -52.05), 4.3016],
	["box", Vector3(37.85, 0.0, -78.67), 0.2017],
	["box", Vector3(-16.13, 0.0, -31.50), 5.9245],
	["coin-silver", Vector3(31.20, 0.0, -65.34), 2.4858],
	["box", Vector3(45.40, 0.0, -63.51), 1.5496],
	["coin-gold", Vector3(-37.05, 0.0, -57.52), 5.6412],
	["cone", Vector3(-29.47, 0.0, -39.21), 3.2014],
	["box", Vector3(14.24, 0.0, -45.42), 3.9424],
	["box", Vector3(13.24, 0.0, -74.46), 2.3978],
	["cone", Vector3(56.72, 0.0, -50.69), 5.4084],
	["coin-silver", Vector3(66.05, 0.0, -47.61), 3.3739],
	["box", Vector3(-6.59, 0.0, -18.95), 2.7317],
	["cone", Vector3(-72.98, 0.0, -39.08), 1.6549],
	["cone", Vector3(-32.97, 0.0, -50.06), 5.4696],
	["coin-gold", Vector3(-18.69, 0.0, -20.26), 0.9603],
	["coin-silver", Vector3(4.50, 0.0, -78.55), 3.3323],
	["box", Vector3(44.41, 0.0, -49.92), 5.8377],
	["banana", Vector3(51.46, 0.0, -74.55), 0.3640],
	["box", Vector3(54.68, 0.0, -76.32), 3.0536],
	["coin-silver", Vector3(61.69, 0.0, -35.67), 0.8067],
	["box", Vector3(-57.14, 0.0, -45.53), 5.4817],
	["coin-gold", Vector3(-31.79, 0.0, -41.67), 4.5863],
	["cone", Vector3(13.16, 0.0, -29.24), 4.0833],
	["box", Vector3(-51.92, 0.0, -39.36), 1.4118],
	["box", Vector3(-31.45, 0.0, -24.55), 1.3837],
	["box", Vector3(55.90, 0.0, -36.63), 5.6889],
	["box", Vector3(13.20, 0.0, -58.01), 4.2033],
	["cone", Vector3(6.32, 0.0, -36.17), 3.5880],
	["coin-silver", Vector3(-68.08, 0.0, -44.10), 1.1964],
	["banana", Vector3(42.00, 0.0, -35.35), 2.9344],
	["cone", Vector3(-8.39, 0.0, -81.73), 0.6184],
	["cone", Vector3(-37.19, 0.0, -36.95), 1.5624],
	["banana", Vector3(19.17, 0.0, -25.70), 1.7502],
	["coin-gold", Vector3(0.09, 0.0, -12.53), 5.4120],
	["cone", Vector3(-16.67, 0.0, -52.73), 5.2529],
	["coin-silver", Vector3(73.65, 0.0, -57.27), 1.0450],
	["banana", Vector3(-35.91, 0.0, -48.38), 0.3684],
	["box", Vector3(-56.10, 0.0, -23.32), 4.9265],
	["cone", Vector3(-48.72, 0.0, -42.92), 6.2544],
	["box", Vector3(-62.09, 0.0, -61.35), 1.8643],
	["coin-gold", Vector3(58.22, 0.0, -55.80), 4.6997],
	["coin-gold", Vector3(55.81, 0.0, -39.52), 5.3578],
	["box", Vector3(42.00, 0.0, -18.06), 1.1676],
	["box", Vector3(-53.00, 0.0, -68.02), 0.7533],
	["coin-gold", Vector3(29.87, 0.0, -62.31), 3.8917],
	["coin-gold", Vector3(-52.08, 0.0, 64.48), 5.8729],
	["box", Vector3(18.71, 0.0, 81.65), 2.4868],
	["banana", Vector3(-20.18, 0.0, 31.17), 4.7241],
	["cone", Vector3(47.41, 0.0, 61.62), 6.2587],
	["box", Vector3(32.26, 0.0, 58.00), 5.8638],
	["banana", Vector3(53.59, 0.0, 25.11), 0.9912],
	["coin-gold", Vector3(32.86, 0.0, 21.71), 6.2030],
	["coin-silver", Vector3(-3.91, 0.0, 47.16), 1.8811],
	["box", Vector3(-39.13, 0.0, 17.67), 0.7253],
	["box", Vector3(45.38, 0.0, 68.07), 3.8003],
	["coin-gold", Vector3(-7.11, 0.0, 32.77), 1.6587],
	["coin-silver", Vector3(-74.02, 0.0, 52.67), 0.5799],
	["box", Vector3(-36.39, 0.0, 59.48), 4.8451],
	["coin-silver", Vector3(-26.00, 0.0, 34.85), 3.4663],
	["box", Vector3(-6.89, 0.0, 51.68), 5.5487],
	["coin-silver", Vector3(47.43, 0.0, 33.65), 3.6600],
	["banana", Vector3(16.64, 0.0, 61.16), 5.6485],
	["cone", Vector3(20.68, 0.0, 15.33), 1.3199],
	["coin-silver", Vector3(0.07, 0.0, 62.50), 5.5552],
	["box", Vector3(-51.12, 0.0, 67.05), 5.8426],
	["coin-silver", Vector3(50.82, 0.0, 21.03), 5.5381],
	["banana", Vector3(66.13, 0.0, 55.19), 5.8485],
	["coin-silver", Vector3(23.37, 0.0, 15.68), 1.6764],
	["cone", Vector3(5.97, 0.0, 37.53), 5.3947],
	["coin-gold", Vector3(12.15, 0.0, 84.72), 1.9176],
	["box", Vector3(10.46, 0.0, 32.14), 1.2135],
	["cone", Vector3(-34.24, 0.0, 81.96), 1.7538],
	["cone", Vector3(-31.08, 0.0, 30.86), 3.3691],
	["cone", Vector3(24.58, 0.0, 45.07), 1.1220],
	["box", Vector3(39.08, 0.0, 45.31), 2.7304],
	["coin-gold", Vector3(-5.87, 0.0, 28.36), 3.2134],
	["box", Vector3(-44.48, 0.0, 69.56), 4.4534],
	["coin-gold", Vector3(75.04, 0.0, 50.40), 4.5203],
	["banana", Vector3(-3.23, 0.0, 18.10), 0.4397],
	["banana", Vector3(-23.00, 0.0, 30.77), 5.3282],
	["banana", Vector3(-8.07, 0.0, 29.01), 2.5660],
	["box", Vector3(-34.68, 0.0, 62.20), 2.6417],
	["cone", Vector3(59.74, 0.0, 38.25), 3.8674],
	["box", Vector3(-18.17, 0.0, 77.40), 1.8027],
	["coin-silver", Vector3(-53.73, 0.0, 62.67), 2.9216],
	["coin-gold", Vector3(-33.70, 0.0, 56.41), 5.6623],
	["box", Vector3(9.16, 0.0, 34.60), 3.2387],
	["coin-silver", Vector3(-30.30, 0.0, 33.26), 4.7195],
	["box", Vector3(-17.24, 0.0, 33.65), 0.1535],
	["coin-silver", Vector3(1.74, 0.0, 76.87), 0.4576],
	["box", Vector3(-53.17, 0.0, 65.85), 4.3753],
	["coin-silver", Vector3(-38.50, 0.0, 50.68), 0.0348],
	["box", Vector3(0.41, 0.0, 15.78), 2.6713],
	["coin-gold", Vector3(34.28, 0.0, 84.11), 0.3155],
	["coin-gold", Vector3(0.36, 0.0, 85.92), 5.0354],
	["coin-gold", Vector3(-38.38, 0.0, 16.32), 5.9693],
	["coin-silver", Vector3(47.39, 0.0, 30.75), 3.1716],
	["cone", Vector3(27.99, 0.0, 24.75), 4.6725],
	["box", Vector3(-39.21, 0.0, 53.15), 4.0065],
	["coin-gold", Vector3(5.59, 0.0, 21.98), 1.7253],
	["box", Vector3(36.85, 0.0, 59.75), 2.0088],
	["box", Vector3(-28.10, 0.0, 46.38), 4.3602],
	["banana", Vector3(-5.35, 0.0, 40.48), 3.4093],
	["banana", Vector3(-30.62, 0.0, 58.95), 5.6853],
	["coin-silver", Vector3(-56.18, 0.0, 33.61), 4.8104],
	["banana", Vector3(-32.30, 0.0, -133.41), 4.7342],
	["banana", Vector3(95.43, 0.0, 122.43), 4.6968],
	["banana", Vector3(-17.32, 0.0, -127.16), 4.2672],
	["banana", Vector3(33.01, 0.0, -127.72), 3.5462],
	["box", Vector3(-127.68, 0.0, 38.54), 2.9009],
	["box", Vector3(-121.42, 0.0, -32.64), 2.0536],
	["box", Vector3(-66.89, 0.0, -112.89), 3.3893],
	["coin-silver", Vector3(134.98, 0.0, -40.51), 4.9086],
	["box", Vector3(121.40, 0.0, -81.17), 0.9574],
	["coin-silver", Vector3(66.94, 0.0, -104.08), 6.0615],
	["banana", Vector3(-105.81, 0.0, -128.07), 4.2559],
	["coin-silver", Vector3(123.71, 0.0, -27.90), 0.4775],
	["coin-silver", Vector3(-107.49, 0.0, 73.57), 3.7725],
	["coin-silver", Vector3(-102.32, 0.0, 130.64), 2.1815],
	["box", Vector3(94.39, 0.0, 87.03), 6.0368],
	["box", Vector3(63.12, 0.0, 125.68), 5.0781],
	["cone", Vector3(89.30, 0.0, -111.60), 1.5322],
	["coin-silver", Vector3(-32.67, 0.0, -127.25), 1.1425],
	["box", Vector3(-132.26, 0.0, 120.98), 4.5244],
	["coin-silver", Vector3(-109.88, 0.0, -75.17), 1.9239],
	["box", Vector3(-67.12, 0.0, -102.42), 0.7512],
	["box", Vector3(128.68, 0.0, 6.65), 0.6316],
	["coin-gold", Vector3(-86.55, 0.0, -131.18), 1.7235],
	["coin-silver", Vector3(128.06, 0.0, 14.41), 0.7934],
	["cone", Vector3(99.48, 0.0, -2.46), 3.6070],
	["cone", Vector3(-85.22, 0.0, -121.13), 3.0017],
	["box", Vector3(-115.00, 0.0, 34.95), 0.9374],
	["coin-silver", Vector3(133.36, 0.0, -103.02), 3.8096],
	["coin-gold", Vector3(132.31, 0.0, -52.55), 3.8304],
	["box", Vector3(64.82, 0.0, 120.85), 1.3259],
	["box", Vector3(-88.07, 0.0, -114.73), 2.8306],
	["coin-silver", Vector3(50.59, 0.0, 114.46), 3.9274],
	["banana", Vector3(43.52, 0.0, 117.09), 3.4216],
	["coin-silver", Vector3(39.86, 0.0, 110.27), 0.4487],
	["coin-silver", Vector3(-57.08, 0.0, -101.42), 4.3966],
	["coin-gold", Vector3(119.52, 0.0, 0.13), 0.5054],
	["banana", Vector3(-124.24, 0.0, -18.35), 1.5731],
	["coin-silver", Vector3(-110.34, 0.0, 124.72), 3.6141],
	["coin-silver", Vector3(121.71, 0.0, 134.88), 1.6934],
	["coin-gold", Vector3(-124.14, 0.0, 69.19), 4.0936],
	["coin-gold", Vector3(112.34, 0.0, -86.00), 3.9885],
	["banana", Vector3(-2.23, 0.0, -110.36), 2.0942],
	["coin-silver", Vector3(-57.18, 0.0, 120.20), 3.4564],
	["banana", Vector3(-47.72, 0.0, 126.95), 3.2333],
	["coin-gold", Vector3(131.79, 0.0, 42.57), 2.5965],
	["coin-gold", Vector3(13.29, 0.0, 115.47), 4.3872],
	["coin-gold", Vector3(-102.21, 0.0, 127.75), 1.5036],
	["coin-gold", Vector3(-92.24, 0.0, 13.73), 0.5857],
	["coin-gold", Vector3(132.91, 0.0, 111.49), 0.7381],
	["coin-silver", Vector3(89.68, 0.0, -0.44), 3.1973],
	["coin-gold", Vector3(129.67, 0.0, -69.19), 2.4101],
	["cone", Vector3(113.90, 0.0, 2.23), 5.4288],
	["coin-gold", Vector3(-22.97, 0.0, 117.25), 5.1557],
	["coin-gold", Vector3(23.47, 0.0, 134.70), 0.9337],
	["coin-silver", Vector3(74.40, 0.0, -123.22), 4.4311],
	["box", Vector3(129.82, 0.0, -1.26), 3.1560],
	["coin-gold", Vector3(101.03, 0.0, -16.12), 2.8710],
	["banana", Vector3(-8.24, 0.0, 126.68), 4.3524],
	["banana", Vector3(95.13, 0.0, 97.02), 1.9896],
	["box", Vector3(100.54, 0.0, -125.31), 3.9657],
	["coin-silver", Vector3(113.65, 0.0, 134.30), 2.7267],
	["coin-silver", Vector3(100.60, 0.0, -15.21), 5.6764],
	["banana", Vector3(-122.58, 0.0, 79.96), 2.3552],
	["coin-gold", Vector3(-95.70, 0.0, 8.41), 4.9795],
	["cone", Vector3(-89.10, 0.0, -113.68), 3.8938],
	["box", Vector3(-69.98, 0.0, 111.46), 2.8975],
	["cone", Vector3(-132.46, 0.0, 82.25), 4.2576],
	["cone", Vector3(133.03, 0.0, -55.29), 4.1358],
	["coin-gold", Vector3(-121.76, 0.0, 28.73), 5.6810],
	["coin-silver", Vector3(34.63, 0.0, 108.92), 1.9411],
	["banana", Vector3(62.74, 0.0, -110.66), 4.6966],
	["coin-gold", Vector3(-87.58, 0.0, -99.32), 6.1040],
	["coin-silver", Vector3(8.33, 0.0, 111.64), 1.6146],
	["coin-silver", Vector3(87.67, 0.0, -4.90), 4.6908],
	["cone", Vector3(-43.55, 0.0, -103.90), 0.8844],
	["coin-silver", Vector3(125.96, 0.0, 97.24), 6.1572],
	["banana", Vector3(126.16, 0.0, 82.24), 4.9680],
	["coin-gold", Vector3(-131.24, 0.0, 9.87), 4.2275],
	["box", Vector3(87.05, 0.0, 118.88), 1.4691],
	["coin-gold", Vector3(-128.24, 0.0, 103.74), 5.7507],
	["coin-silver", Vector3(-75.23, 0.0, -117.93), 5.7139],
	["banana", Vector3(-97.26, 0.0, 120.49), 3.0953],
	["box", Vector3(-108.76, 0.0, 104.56), 2.8503],
	["coin-silver", Vector3(120.41, 0.0, -21.84), 0.9709],
	["coin-gold", Vector3(-22.98, 0.0, -108.26), 2.5643],
	["banana", Vector3(121.91, 0.0, -126.17), 2.7859],
	["box", Vector3(121.65, 0.0, 95.97), 4.3083],
	["banana", Vector3(12.01, 0.0, 129.02), 2.5016],
	["coin-silver", Vector3(-83.75, 0.0, -102.02), 2.8571],
	["coin-silver", Vector3(26.23, 0.0, -129.23), 1.5304],
	["box", Vector3(-101.00, 0.0, 17.44), 4.8076],
	["box", Vector3(-95.16, 0.0, 108.14), 5.3935],
	["box", Vector3(-95.93, 0.0, -99.90), 1.0964],
	["box", Vector3(43.49, 0.0, -128.04), 4.9636],
	["coin-silver", Vector3(-87.95, 0.0, -120.85), 3.3055],
	["box", Vector3(75.06, 0.0, 3.57), 3.1657],
	["coin-silver", Vector3(120.26, 0.0, -123.29), 5.4474],
	["coin-gold", Vector3(125.29, 0.0, -118.58), 2.5234],
	["box", Vector3(110.62, 0.0, -115.16), 3.8220],
	["coin-gold", Vector3(-117.27, 0.0, -60.75), 3.4454],
	["coin-gold", Vector3(-47.20, 0.0, 133.55), 2.8508],
	["coin-silver", Vector3(28.47, 0.0, -108.22), 5.3583],
	["banana", Vector3(-22.68, 0.0, -109.33), 4.1790],
	["coin-silver", Vector3(114.21, 0.0, -116.87), 0.5858],
	["coin-silver", Vector3(67.58, 0.0, 99.38), 6.0846],
	["banana", Vector3(-105.78, 0.0, 93.25), 4.7916],
	["coin-silver", Vector3(93.19, 0.0, 128.13), 3.8552],
	["cone", Vector3(38.53, 0.0, -127.91), 5.2117],
	["cone", Vector3(-43.25, 0.0, -133.35), 3.5583],
	["coin-silver", Vector3(35.96, 0.0, -126.72), 1.3517],
	["box", Vector3(-112.06, 0.0, -120.80), 3.8820],
	["coin-gold", Vector3(68.83, 0.0, -104.27), 1.7797],
	["banana", Vector3(45.13, 0.0, -122.74), 3.7657],
	["box", Vector3(-132.92, 0.0, -53.62), 0.8623],
	["box", Vector3(-132.91, 0.0, 66.69), 2.3889],
	["box", Vector3(-115.54, 0.0, 97.68), 0.1178],
	["coin-gold", Vector3(113.71, 0.0, 97.77), 3.6028],
	["banana", Vector3(-103.90, 0.0, -129.37), 5.0349],
	["coin-silver", Vector3(113.34, 0.0, -111.20), 1.5288],
	["box", Vector3(-89.60, 0.0, 2.83), 3.2041],
	["coin-silver", Vector3(73.67, 0.0, -1.59), 4.7744],
	["coin-gold", Vector3(-13.80, 0.0, 114.52), 3.9917],
	["banana", Vector3(-116.56, 0.0, -15.60), 1.7258],
	["banana", Vector3(-119.83, 0.0, 1.98), 2.8395],
	["box", Vector3(-119.64, 0.0, 89.56), 5.4302],
	["coin-silver", Vector3(106.89, 0.0, -13.57), 4.0956],
	["box", Vector3(-94.27, 0.0, -118.29), 5.6494],
	["coin-silver", Vector3(-117.20, 0.0, -109.48), 1.7853],
	["banana", Vector3(109.71, 0.0, 100.79), 3.6615],
	["banana", Vector3(126.28, 0.0, 53.59), 3.7388],
	["banana", Vector3(118.26, 0.0, -51.41), 4.9742],
	["box", Vector3(120.87, 0.0, -3.71), 0.8643],
	["box", Vector3(-114.17, 0.0, 93.00), 4.8435],
	["box", Vector3(90.48, 0.0, 103.59), 2.1160],
	["banana", Vector3(71.90, 0.0, -99.62), 1.0194],
	["coin-gold", Vector3(83.44, 0.0, -90.30), 2.5815],
	["coin-silver", Vector3(83.33, 0.0, -8.37), 2.3112],
	["coin-gold", Vector3(120.73, 0.0, 130.80), 1.7704],
	["coin-silver", Vector3(125.89, 0.0, 85.56), 0.8696],
	["box", Vector3(101.01, 0.0, 14.73), 5.3149],
	["coin-gold", Vector3(109.43, 0.0, -95.22), 5.9465],
	["box", Vector3(-40.61, 0.0, -127.80), 3.1542],
	["banana", Vector3(-71.34, 0.0, 133.52), 0.1771],
	["coin-silver", Vector3(116.32, 0.0, 91.58), 4.9724],
	["box", Vector3(-13.88, 0.0, -133.58), 1.6080],
	["coin-silver", Vector3(90.44, 0.0, 13.18), 3.3161],
	["banana", Vector3(-53.69, 0.0, -122.11), 4.9882],
	["box", Vector3(109.39, 0.0, 26.12), 3.2382],
	["coin-gold", Vector3(-69.68, 0.0, -96.23), 3.8630],
	["cone", Vector3(44.38, 0.0, -111.88), 0.4252],
]


func _ready() -> void:
	# Cull ~55% of decor on mobile/web platforms for performance
	var is_low_perf: bool = OS.has_feature("mobile") or OS.has_feature("web")
	var skip_n: int = 2 if is_low_perf else 1  # keep every Nth item on low-perf
	var i: int = 0
	for entry in ALL_ITEMS:
		i += 1
		if is_low_perf and (i % skip_n) != 0:
			continue
		var key: String = entry[0]
		var pos: Vector3 = entry[1]
		var yaw: float = entry[2]
		var glb_path: String = TOY_MAP.get(key, "")
		if glb_path == "":
			continue
		_spawn_collidable(glb_path, pos, yaw, SCALE_TOY)

	# Start line flag towers (×18)
	_spawn_collidable(FLAG_GLB, Vector3(55.69982, 0.0, -1.11144), 0.0, SCALE_FLAG)
	_spawn_collidable(FLAG_GLB, Vector3(51.46554, 0.0, -14.45576), 0.0, SCALE_FLAG)

	# 4 corner pylons (×10)
	_spawn_collidable(PYLON_GLB, Vector3(112.79625, 0.0, -53.54827), 0.0, SCALE_PYLON)
	_spawn_collidable(PYLON_GLB, Vector3(-112.79625, 0.0, -53.54827), 0.0, SCALE_PYLON)
	_spawn_collidable(PYLON_GLB, Vector3(112.79625, 0.0, 53.54827), 0.0, SCALE_PYLON)
	_spawn_collidable(PYLON_GLB, Vector3(-112.79625, 0.0, 53.54827), 0.0, SCALE_PYLON)

	# Giant food items scattered around the perimeter — picnic-on-pool-table vibe
	_spawn_food_scatter()

	# Painted "START" text on the ground at the start line
	_spawn_start_label()

	# Hot Wheels visual flair — giant loops + banked ramps as pure decor (no collision)
	_spawn_hot_wheels_decor()


func _spawn_hot_wheels_decor() -> void:
	# 2 giant loops at the figure-8 extremities, scaled ×6, positioned alongside the track
	# (not over it — cars don't pass through them, they're decorative landmarks)
	var loop_glb: String = "res://assets/toy_kit/track-narrow-looping.glb"
	_spawn_visual(loop_glb, Vector3(0, 0, -135), 0.0, 6.0)
	_spawn_visual(loop_glb, Vector3(0, 0, +135), PI, 6.0)

	# 4 banked corner ramps outside the figure-8 corners
	var ramp_glb: String = "res://assets/toy_kit/track-narrow-corner-large-ramp.glb"
	_spawn_visual(ramp_glb, Vector3(115, 0, -115), -PI/4.0, 5.0)
	_spawn_visual(ramp_glb, Vector3(-115, 0, -115), PI/4.0, 5.0)
	_spawn_visual(ramp_glb, Vector3(115, 0, +115), -PI*0.75, 5.0)
	_spawn_visual(ramp_glb, Vector3(-115, 0, +115), PI*0.75, 5.0)

	# Finish gate arch over the start line — scenic
	var gate_glb: String = "res://assets/toy_kit/gate-finish.glb"
	_spawn_visual(gate_glb, Vector3(58.0, 0.0, -8.0), atan2(0.95317, 0.30245), 6.0)


func _spawn_visual(glb_path: String, world_pos: Vector3, yaw_rad: float, scale_factor: float) -> void:
	# Visual-only spawn (no collision) for huge decor that shouldn't block cars.
	var packed: PackedScene = load(glb_path) as PackedScene
	if packed == null:
		push_warning("decor: failed to load %s" % glb_path)
		return
	var inst: Node3D = packed.instantiate() as Node3D
	if inst == null:
		return
	inst.name = "%s_visual_%d" % [glb_path.get_file().get_basename(), get_child_count()]
	var b: Basis = Basis(Vector3.UP, yaw_rad).scaled(Vector3.ONE * scale_factor)
	inst.transform = Transform3D(b, world_pos)
	add_child(inst)


func _spawn_food_scatter() -> void:
	# 18 random food items at corners of the floor (outside both ovals, far enough to not clutter the track)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1337
	var food_positions: Array[Vector3] = [
		Vector3(125, 0, -120), Vector3(-130, 0, -125), Vector3(120, 0, 130), Vector3(-125, 0, 120),
		Vector3(130, 0, 0), Vector3(-130, 0, 5), Vector3(0, 0, -130), Vector3(8, 0, 130),
		Vector3(60, 0, -125), Vector3(-65, 0, -120), Vector3(70, 0, 125), Vector3(-60, 0, 130),
		Vector3(125, 0, -65), Vector3(-130, 0, -55), Vector3(125, 0, 70), Vector3(-130, 0, 60),
		Vector3(110, 0, -10), Vector3(-115, 0, 12),
	]
	for pos in food_positions:
		var glb_path: String = FOOD_GLBS[rng.randi() % FOOD_GLBS.size()]
		var yaw: float = rng.randf_range(0.0, TAU)
		_spawn_collidable(glb_path, pos, yaw, SCALE_FOOD)


func _spawn_start_label() -> void:
	# Big painted "START" letters on the ground in front of the start line, facing the racing direction.
	var label: Label3D = Label3D.new()
	label.name = "StartGroundLabel"
	label.text = "START"
	label.font_size = 256
	label.outline_size = 24
	label.modulate = Color(1, 0.9, 0.1, 1)
	label.outline_modulate = Color(0.05, 0.05, 0.05, 1)
	label.no_depth_test = false
	label.pixel_size = 0.06
	# Place the text laying flat on the ground (rotate -90° around X so it reads facing up)
	# at world (60, 0.06, -10) which is ~3m in front of the start stripe along the racing tangent
	var b: Basis = Basis().rotated(Vector3.RIGHT, -PI / 2.0)
	# Then yaw to align with the start line direction
	b = b.rotated(Vector3.UP, atan2(0.95317, 0.30245))  # rotate to match start tangent
	label.transform = Transform3D(b, Vector3(60.0, 0.06, -10.0))
	add_child(label)


func _spawn_collidable(glb_path: String, world_pos: Vector3, yaw_rad: float, scale_factor: float) -> void:
	var packed: PackedScene = load(glb_path) as PackedScene
	if packed == null:
		push_warning("decor: failed to load %s" % glb_path)
		return
	var inst: Node3D = packed.instantiate() as Node3D
	if inst == null:
		return

	# Wrap in a StaticBody3D so we can attach collision
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "%s_%d" % [glb_path.get_file().get_basename(), get_child_count()]
	var b: Basis = Basis(Vector3(0, 1, 0), yaw_rad).scaled(Vector3.ONE * scale_factor)
	body.transform = Transform3D(b, world_pos)
	add_child(body)

	# Mesh as child (local identity)
	body.add_child(inst)
	inst.transform = Transform3D.IDENTITY

	# Compute AABB from all child MeshInstance3D and add a BoxShape3D collision
	var aabb: AABB = _compute_mesh_aabb(inst)
	if aabb.size.length() > 0.01:
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = aabb.size
		shape_node.shape = box
		shape_node.position = aabb.get_center()
		body.add_child(shape_node)


func _compute_mesh_aabb(node: Node) -> AABB:
	var result: AABB = AABB()
	var found_any: bool = false
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var mesh_aabb: AABB = mi.get_aabb()
			# Transform AABB to parent space
			mesh_aabb = mi.transform * mesh_aabb
			if found_any:
				result = result.merge(mesh_aabb)
			else:
				result = mesh_aabb
				found_any = true
		else:
			var sub: AABB = _compute_mesh_aabb(child)
			if sub.size.length() > 0.001:
				if child is Node3D:
					sub = (child as Node3D).transform * sub
				if found_any:
					result = result.merge(sub)
				else:
					result = sub
					found_any = true
	return result
