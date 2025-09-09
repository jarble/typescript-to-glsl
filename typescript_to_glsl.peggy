// --- Comment statement demonstration ---

// Type alias
type Vec2 = vec2;

// Enum
enum Direction {
  Up,
  Down,
  Left,
  Right
}

// Function declaration only (prototype)
function add(x: Vec2, y: Vec2): Vec2;

// Function declaration with body
function add(x: Vec2, y: Vec2): Vec2 {
  return x + y;
}

// Constant declaration
const PI: float = 3.14159;

// Variable declaration
let counter: int = 0;

function main(): void {
  let z: int = 5;

  // Simple assignment
  z = z + 1;

  // Compound assignment
  z += 2;
  z -= 1;
  z *= 3;
  z /= 2;
  

  // Bitwise assignments
  z |= 3;
  z &= 7;
  z ^= 1;
  z <<= 2;
  z >>= 1;

  // If statement
  if (z > 0) {
    printInt(z);
  } else {
    printInt(-z);
  }

  // For loop
  for (let i: int = 0; i < 3; i++) {
    printInt(i);
  }

  // While loop
  while (z < 20) {
    z++;
  }

  // Do-while loop
  do {
    z--;
  } while (z > 10);

  // Switch statement
  switch (z) {
    case 5:
      printStr("Five");
      break;
    case 10:
      printStr("Ten");
      break;
    default:
      printStr("Other");
  }
}
