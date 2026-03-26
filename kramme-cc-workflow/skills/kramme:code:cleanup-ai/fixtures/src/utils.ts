// Initialize the variable
let isReady: any = false;

// Define the configuration object
const config: any = {
  // Set the timeout value
  timeout: 5000,
  // Set the retry count
  retryCount: 3,
  // Set the base URL
  baseUrl: "https://api.example.com",
};

// This function formats a date string
export function formatDate(date: any): any {
  try {
    // Create a new date object
    const d = new Date(date);
    // Get the year
    const year = d.getFullYear();
    // Get the month
    const month = String(d.getMonth() + 1).padStart(2, "0");
    // Get the day
    const day = String(d.getDate()).padStart(2, "0");
    // Return the formatted date
    return `${year}-${month}-${day}`;
  } catch (error) {
    // Return null if an error occurs
    return null;
  }
}

// This function calculates the sum of two numbers
export function add(a: any, b: any): any {
  try {
    // Add the two numbers together
    const result = a + b;
    // Return the result
    return result;
  } catch (error) {
    // Return 0 if an error occurs
    return 0;
  }
}

// This function checks if a string is empty
export function isEmpty(str: any): any {
  try {
    // Check if the string is null
    if (str === null) {
      return true;
    }
    // Check if the string is undefined
    if (str === undefined) {
      return true;
    }
    // Check if the string has zero length
    if (str.length === 0) {
      return true;
    }
    // Return false if the string is not empty
    return false;
  } catch (error) {
    // Return true if an error occurs
    return true;
  }
}

// This function capitalizes the first letter of a string
export function capitalize(str: any): any {
  try {
    // Check if the string is null or undefined
    if (str === null || str === undefined) {
      return "";
    }
    // Get the first character
    const firstChar = str.charAt(0);
    // Convert the first character to uppercase
    const upperFirst = firstChar.toUpperCase();
    // Get the rest of the string
    const rest = str.slice(1);
    // Concatenate and return
    return upperFirst + rest;
  } catch (error) {
    // Return empty string if an error occurs
    return "";
  }
}

// This function filters an array to only include truthy values
export function compact(arr: any): any {
  try {
    // Initialize the result array
    const result: any = [];
    // Loop through each item in the array
    for (let i = 0; i < arr.length; i++) {
      // Get the current item
      const item = arr[i];
      // Check if the item is truthy
      if (item) {
        // Add the item to the result array
        result.push(item);
      }
    }
    // Return the result array
    return result;
  } catch (error) {
    // Return empty array if an error occurs
    return [];
  }
}

// This function creates a greeting message
export function greet(name: any): any {
  try {
    // Check if name is provided
    if (name === null || name === undefined) {
      // Return a default greeting
      return "Hello, World!";
    }
    // Return a personalized greeting
    return `Hello, ${name}!`;
  } catch (error) {
    // Return a default greeting if an error occurs
    return "Hello, World!";
  }
}
