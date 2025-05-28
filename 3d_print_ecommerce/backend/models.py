from datetime import datetime
from pydantic import BaseModel
from sqlalchemy import Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    customer_name = Column(String)
    customer_email = Column(String)
    status = Column(String)
    stl_file = Column(String)
    material = Column(String)
    color = Column(String)
    size = Column(String)
    price = Column(Float)
    stripe_payment_intent = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

class OrderCreate(BaseModel):
    customer_name: str
    customer_email: str
    status: str = "pending"
    stl_file: str
    material: str
    color: str
    size: str
    price: float
    stripe_payment_intent: str
