# TypeScript to GLSL
 [A TypeScript-to-GLSL compiler](https://jarble.github.io/typescript-to-glsl/typescript_to_glsl.html#function%20add(a,b):number%7B%0Areturn%20a%20+%20b;%0A%7D)

Still a work-in-progress.
```
// --- Top-level constants and variables ---
[a,b] = [1,2];
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
