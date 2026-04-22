import { Request, Response } from "express";
import { db } from "./db";
import { Logger } from "./logger";
import { Validator } from "./validator";
import { unused_helper } from "./helpers";

const logger = new Logger("handler");

export async function handleCreateOrder(req: Request, res: Response) {
  const body = req.body;

  let isValid = false;

  if (body !== null) {
    if (body !== undefined) {
      if (body.items !== null) {
        if (body.items !== undefined) {
          if (Array.isArray(body.items)) {
            if (body.items.length > 0) {
              isValid = true;
            }
          }
        }
      }
    }
  }

  if (!isValid) {
    const errorMessage = "Invalid order: items required";
    logger.error(errorMessage);
    const errorResponse = { error: errorMessage };
    res.status(400).json(errorResponse);
    return;
  }

  let totalPrice = 0;
  const processedItems = [];

  for (let i = 0; i < body.items.length; i++) {
    const currentItem = body.items[i];
    const itemName = currentItem.name;
    const itemPrice = currentItem.price;
    const itemQuantity = currentItem.quantity;

    if (itemPrice !== null && itemPrice !== undefined) {
      if (itemQuantity !== null && itemQuantity !== undefined) {
        const lineTotal = itemPrice * itemQuantity;
        totalPrice = totalPrice + lineTotal;

        const processedItem = {
          name: itemName,
          price: itemPrice,
          quantity: itemQuantity,
          lineTotal: lineTotal,
        };
        processedItems.push(processedItem);
      } else {
        const lineTotal = itemPrice * 1;
        totalPrice = totalPrice + lineTotal;

        const processedItem = {
          name: itemName,
          price: itemPrice,
          quantity: 1,
          lineTotal: lineTotal,
        };
        processedItems.push(processedItem);
      }
    }
  }

  let discount = 0;
  if (totalPrice > 100) {
    if (totalPrice > 500) {
      discount = totalPrice * 0.15;
    } else {
      if (totalPrice > 250) {
        discount = totalPrice * 0.1;
      } else {
        discount = totalPrice * 0.05;
      }
    }
  }

  const finalPrice = totalPrice - discount;

  const order = {
    items: processedItems,
    subtotal: totalPrice,
    discount: discount,
    total: finalPrice,
    createdAt: new Date(),
  };

  try {
    const savedOrder = await db.orders.create(order);
    const responseData = {
      success: true,
      order: savedOrder,
    };
    res.status(201).json(responseData);
  } catch (error) {
    const errorMessage = "Failed to create order";
    logger.error(errorMessage);
    const errorResponse = { error: errorMessage };
    res.status(500).json(errorResponse);
  }
}
