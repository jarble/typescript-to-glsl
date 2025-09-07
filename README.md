# TypeScript to GLSL
 [A TypeScript-to-GLSL compiler](https://jarble.github.io/typescript-to-glsl/typescript_to_glsl.html#function%20add(a,b):number%7B%0Areturn%20a%20+%20b;%0A%7D)

Still a work-in-progress.
## TypeScript input:
```
// --- Top-level constants and variables ---
const PI = Math.PI;
var a = "Hello";
a[0] /= 1;

var nums = [1,2,3,4];
var grid: number[][] = [
    [1,2],
    [3,4]
];
var message = "Hello";  // will be converted to float[]

// --- Top-level increment/decrement ---
nums[2]++;
nums[1]--;

// --- Class declaration ---
class Vec2 {
    x: number;
    y: number;
}

// --- Function declarations ---
function add(a: number, b: number): number {
    return a + b;
}

function computePower(a: number, b: number): number {
    var result: number = a ** b;
    return result;
}


function matrixSum(m: number[][]): number {
    var sum: number = 0;
    for(var i:float = 0; i < 2; i++){
        for(var j:float = 0; j < 2; j++){
            sum += m[i][j];
        }
    }
    return sum;
}

function chooseValue(x: number): number {
    return x > 5 ? 10 : x == 5 ? 5 : 0;
}

// --- Main function demonstrating features ---
function main(): void {
    
    var intensity:float = pos.x * grid[0][1];

    // Math functions
    var angle: number = Math.atan2(pos.y, pos.x);
    var maxVal: number = Math.max(nums[0], nums[1]);

    // Increment/decrement
    nums[0]++;
    nums[1]--;

    // Ternary usage
    var val:float = chooseValue(nums[0]);

    // If/else
    if(nums[0] > 5){
        nums[0] = 0;
    } else if(nums[0] == 5){
        nums[0] = 1;
    } else {
        nums[0] = -1;
    }

    // While loop
    var counter: number = 0;
    while(counter < 3){
        counter++;
    }

    // Do-while loop
    var d: number = 0;
    do {
        d++;
    } while(d < 2);

    // Switch statement
    switch(nums[0]){
        case 0:
            nums[0] = 100;
            break;
        case 1:
            nums[0] = 200;
            break;
        default:
            nums[0] = -1;
    }

    // Compute matrix sum
    var total:float = matrixSum(grid);

    // Compute power
    var power: number = computePower(2,3);

    // Log all results (just for demonstration)

}

// Execute main
main();
```
## GLSL output:
```
// --- Top-level constants and variables ---

a_compiled = 1.0;
b_compiled = 2.0;
#define PI_compiled Math_compiled.PI_compiled

#define a_compiled float[](72.0,101.0,108.0,108.0,111.0)

a_compiled[0.0] /= 1.0;
#define nums_compiled [object Object]

float[][] grid_compiled = [object Object];
#define message_compiled float[](72.0,101.0,108.0,108.0,111.0)

// will be converted to float[]

// --- Top-level increment/decrement ---

nums_compiled[2.0]++;
nums_compiled[1.0]--;
// --- Class declaration ---

typedef struct {
float x_compiled;
float y_compiled;
} Vec2_compiled;

// --- Function declarations ---

float add_compiled(float a_compiled, float b_compiled) {
return a_compiled + b_compiled;
}
float computePower_compiled(float a_compiled, float b_compiled) {
float result_compiled = pow(a_compiled, b_compiled);
return result_compiled;
}
float matrixSum_compiled(float[][] m_compiled) {
float sum_compiled = 0.0;
for(float_compiled i_compiled = 0.0;i_compiled < 2.0;i_compiled++) {
for(float_compiled j_compiled = 0.0;j_compiled < 2.0;j_compiled++) {
sum_compiled += m_compiled[i_compiled][j_compiled];
}
}
return sum_compiled;
}
float chooseValue_compiled(float x_compiled) {
return x_compiled > 5.0 ? 10.0 : x_compiled == 5.0 ? 5.0 : 0.0;
}
// --- Main function demonstrating features ---

void_compiled main_compiled() {
float_compiled intensity_compiled = pos_compiled.x_compiled * grid_compiled[0.0][1.0];
// Math functions

float angle_compiled = Math.atan2_compiled(pos_compiled.y_compiled,pos_compiled.x_compiled);
float maxVal_compiled = max(nums_compiled[0.0],nums_compiled[1.0]);
// Increment/decrement

nums_compiled[0.0]++;
nums_compiled[1.0]--;
// Ternary usage

float_compiled val_compiled = chooseValue_compiled(nums_compiled[0.0]);
// If/else

if(nums_compiled[0.0] > 5.0) {
nums_compiled[0.0] = 0.0;
} else if(nums_compiled[0.0] == 5.0) {
nums_compiled[0.0] = 1.0;
} else {
nums_compiled[0.0] = -1.0;
}
// While loop

float counter_compiled = 0.0;
while(counter_compiled < 3.0) {
counter_compiled++;
}
// Do-while loop

float d_compiled = 0.0;
do {
d_compiled++;
} while(d_compiled < 2.0);
// Switch statement

switch(nums_compiled[0.0]) {
case 0.0:
nums_compiled[0.0] = 100.0;break_compiled;case 1.0:
nums_compiled[0.0] = 200.0;break_compiled;default:
nums_compiled[0.0] = -1.0;
}
// Compute matrix sum

float_compiled total_compiled = matrixSum_compiled(grid_compiled);
// Compute power

float power_compiled = computePower_compiled(2.0,3.0);
// Log all results (just for demonstration)

}
// Execute main

main_compiled();
```
