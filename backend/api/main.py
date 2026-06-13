import os
import uuid
import calendar
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List
from supabase import create_client, Client
from dotenv import load_dotenv

# Load env variables for local testing
load_dotenv()

app = FastAPI(
    title="Expense & Debt Tracker API",
    description="Backend API serving the Expense & Debt Tracker app, connected to Supabase.",
    version="1.0.0"
)

# Enable CORS for Flutter Client access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Supabase Credentials Configuration
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

supabase_client: Optional[Client] = None
is_mock_mode = False

if SUPABASE_URL and SUPABASE_KEY:
    try:
        supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("Successfully connected to Supabase!")
    except Exception as e:
        print(f"Error initializing Supabase client: {e}. Running in Mock Mode.")
        is_mock_mode = True
else:
    print("Supabase credentials missing from environment variables. Running in Mock Mode.")
    is_mock_mode = True

# --- IN-MEMORY MOCK DATA STORE ---
# Used if Supabase credentials are not supplied.
mock_transactions = [
    {
        "id": "e81f185b-fc13-4f01-bb1c-4395df3d01cb",
        "type": "gain",
        "amount": 5000.0,
        "description": "Monthly Salary payout",
        "timestamp": (datetime.now(timezone.utc).replace(day=1)).isoformat()
    },
    {
        "id": "f5b61e2a-19c2-402a-bf31-01f654bda309",
        "type": "spend",
        "amount": 1200.0,
        "description": "Appartment Rental payment",
        "timestamp": (datetime.now(timezone.utc).replace(day=2)).isoformat()
    },
    {
        "id": "a90b1c2d-34e5-4f6g-7h8i-9j0k1l2m3n4o",
        "type": "spend",
        "amount": 150.0,
        "description": "Weekly grocery list",
        "timestamp": (datetime.now(timezone.utc).replace(day=5)).isoformat()
    }
]

mock_debts = [
    {
        "id": "3b2c1d0a-9876-5432-10fe-fedcba987654",
        "person_name": "John Doe",
        "original_amount": 1000.0,
        "interest_rate": 8.5,  # 8.5% annual simple interest
        "created_at": (datetime.now(timezone.utc) - timedelta(days=45)).isoformat() if 'timedelta' in globals() else (datetime.now(timezone.utc)).isoformat()
    }
]

# Quick correction for datetime imports in mock values
from datetime import timedelta
mock_debts[0]["created_at"] = (datetime.now(timezone.utc) - timedelta(days=45)).isoformat()


# --- PYDANTIC SCHEMAS ---
class TransactionCreate(BaseModel):
    type: str = Field(..., description="Must be 'gain' or 'spend'")
    amount: float = Field(..., description="Numeric transaction amount")
    description: Optional[str] = Field(None, description="Optional description details")
    timestamp: Optional[datetime] = Field(None, description="Transaction timestamp. Defaults to now.")

class DebtCreate(BaseModel):
    person_name: str = Field(..., description="Name of the person you owe/who owes you")
    original_amount: float = Field(..., description="Principal debt amount")
    interest_rate: float = Field(..., description="Annual interest rate in %")
    created_at: Optional[datetime] = Field(None, description="Debt issue date. Defaults to now.")

class DebtUpdate(BaseModel):
    person_name: Optional[str] = None
    original_amount: Optional[float] = None
    interest_rate: Optional[float] = None
    created_at: Optional[datetime] = None


# --- HELPER FUNCTIONS ---
def parse_date(date_str) -> datetime:
    if not date_str:
        return datetime.now(timezone.utc)
    try:
        dt = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
        if not dt.tzinfo:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt
    except Exception:
        return datetime.now(timezone.utc)

def calculate_debt_interest(debt) -> float:
    """Calculates simple interest accrued from created_at to now."""
    created_at = parse_date(debt.get("created_at"))
    original_amount = float(debt.get("original_amount", 0))
    interest_rate = float(debt.get("interest_rate", 0))
    
    if original_amount <= 0 or interest_rate <= 0:
        return 0.0
        
    now = datetime.now(timezone.utc)
    elapsed = now - created_at
    days_elapsed = max(0.0, elapsed.total_seconds() / 86400.0)
    
    # Simple Interest: Principal * (Rate/100) * (Time_in_years)
    accrued = original_amount * (interest_rate / 100.0) * (days_elapsed / 365.0)
    return round(accrued, 2)


# --- ROUTE HANDLERS ---

@app.get("/")
def get_root():
    return {
        "status": "online",
        "mode": "supabase" if not is_mock_mode else "in-memory-mock",
        "message": "Welcome to the Expense & Debt Tracker API!",
        "datetime": datetime.now(timezone.utc).isoformat()
    }

# --- TRANSACTIONS ENDPOINTS ---

@app.get("/api/transactions")
def get_transactions():
    if not is_mock_mode:
        try:
            res = supabase_client.table("transactions").select("*").order("timestamp", desc=True).execute()
            return res.data
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    else:
        # Sort mock list descending by timestamp
        sorted_txs = sorted(mock_transactions, key=lambda x: x["timestamp"], reverse=True)
        return sorted_txs

@app.post("/api/transactions")
def create_transaction(tx: TransactionCreate):
    if tx.type not in ["gain", "spend"]:
        raise HTTPException(status_code=400, detail="Transaction type must be 'gain' or 'spend'")
    if tx.amount < 0:
        raise HTTPException(status_code=400, detail="Amount cannot be negative")
        
    ts = tx.timestamp if tx.timestamp else datetime.now(timezone.utc)
    
    payload = {
        "type": tx.type,
        "amount": tx.amount,
        "description": tx.description,
        "timestamp": ts.isoformat()
    }
    
    if not is_mock_mode:
        try:
            res = supabase_client.table("transactions").insert(payload).execute()
            return res.data[0]
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Database insert error: {str(e)}")
    else:
        new_tx = {
            "id": str(uuid.uuid4()),
            **payload
        }
        mock_transactions.append(new_tx)
        return new_tx

@app.delete("/api/transactions/{tx_id}")
def delete_transaction(tx_id: str):
    if not is_mock_mode:
        try:
            res = supabase_client.table("transactions").delete().eq("id", tx_id).execute()
            if not res.data:
                raise HTTPException(status_code=404, detail="Transaction not found")
            return {"status": "deleted", "id": tx_id}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Database delete error: {str(e)}")
    else:
        global mock_transactions
        initial_len = len(mock_transactions)
        mock_transactions = [t for t in mock_transactions if t["id"] != tx_id]
        if len(mock_transactions) == initial_len:
            raise HTTPException(status_code=404, detail="Transaction not found")
        return {"status": "deleted", "id": tx_id}

# --- DEBTS ENDPOINTS ---

@app.get("/api/debts")
def get_debts():
    if not is_mock_mode:
        try:
            res = supabase_client.table("debts").select("*").execute()
            debts_list = res.data
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Database fetch error: {str(e)}")
    else:
        debts_list = mock_debts
        
    # Append computed accrued interest and total debt fields
    enriched_debts = []
    for d in debts_list:
        accrued = calculate_debt_interest(d)
        enriched = {
            **d,
            "accrued_interest": accrued,
            "total_debt": round(float(d.get("original_amount", 0)) + accrued, 2)
        }
        enriched_debts.append(enriched)
        
    return enriched_debts

@app.post("/api/debts")
def create_debt(debt: DebtCreate):
    if debt.original_amount < 0:
        raise HTTPException(status_code=400, detail="Original amount cannot be negative")
    if debt.interest_rate < 0:
        raise HTTPException(status_code=400, detail="Interest rate cannot be negative")
        
    created = debt.created_at if debt.created_at else datetime.now(timezone.utc)
    
    payload = {
        "person_name": debt.person_name,
        "original_amount": debt.original_amount,
        "interest_rate": debt.interest_rate,
        "created_at": created.isoformat()
    }
    
    if not is_mock_mode:
        try:
            res = supabase_client.table("debts").insert(payload).execute()
            d = res.data[0]
            accrued = calculate_debt_interest(d)
            return {
                **d,
                "accrued_interest": accrued,
                "total_debt": round(float(d.get("original_amount", 0)) + accrued, 2)
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Database insert error: {str(e)}")
    else:
        new_debt = {
            "id": str(uuid.uuid4()),
            **payload
        }
        mock_debts.append(new_debt)
        accrued = calculate_debt_interest(new_debt)
        return {
            **new_debt,
            "accrued_interest": accrued,
            "total_debt": round(float(new_debt["original_amount"]) + accrued, 2)
        }

@app.put("/api/debts/{debt_id}")
def update_debt(debt_id: str, updates: DebtUpdate):
    payload = {}
    if updates.person_name is not None:
        payload["person_name"] = updates.person_name
    if updates.original_amount is not None:
        if updates.original_amount < 0:
            raise HTTPException(status_code=400, detail="Original amount cannot be negative")
        payload["original_amount"] = updates.original_amount
    if updates.interest_rate is not None:
        if updates.interest_rate < 0:
            raise HTTPException(status_code=400, detail="Interest rate cannot be negative")
        payload["interest_rate"] = updates.interest_rate
    if updates.created_at is not None:
        payload["created_at"] = updates.created_at.isoformat()
        
    if not payload:
        raise HTTPException(status_code=400, detail="No updates provided")
        
    if not is_mock_mode:
        try:
            res = supabase_client.table("debts").update(payload).eq("id", debt_id).execute()
            if not res.data:
                raise HTTPException(status_code=404, detail="Debt profile not found")
            d = res.data[0]
            accrued = calculate_debt_interest(d)
            return {
                **d,
                "accrued_interest": accrued,
                "total_debt": round(float(d.get("original_amount", 0)) + accrued, 2)
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Database update error: {str(e)}")
    else:
        for idx, d in enumerate(mock_debts):
            if d["id"] == debt_id:
                for k, v in payload.items():
                    mock_debts[idx][k] = v
                updated = mock_debts[idx]
                accrued = calculate_debt_interest(updated)
                return {
                    **updated,
                    "accrued_interest": accrued,
                    "total_debt": round(float(updated["original_amount"]) + accrued, 2)
                }
        raise HTTPException(status_code=404, detail="Debt profile not found")

@app.delete("/api/debts/{debt_id}")
def delete_debt(debt_id: str):
    if not is_mock_mode:
        try:
            res = supabase_client.table("debts").delete().eq("id", debt_id).execute()
            if not res.data:
                raise HTTPException(status_code=404, detail="Debt profile not found")
            return {"status": "deleted", "id": debt_id}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Database delete error: {str(e)}")
    else:
        global mock_debts
        initial_len = len(mock_debts)
        mock_debts = [d for d in mock_debts if d["id"] != debt_id]
        if len(mock_debts) == initial_len:
            raise HTTPException(status_code=404, detail="Debt profile not found")
        return {"status": "deleted", "id": debt_id}


# --- ADVANCED REPORTS MODULE ENDPOINT ---

@app.get("/api/reports")
def get_reports(timeframe: str = Query("monthly", description="Must be 'monthly' or 'yearly'")):
    if timeframe not in ["monthly", "yearly"]:
        raise HTTPException(status_code=400, detail="Timeframe must be 'monthly' or 'yearly'")
        
    # 1. Fetch transactions & debts
    if not is_mock_mode:
        try:
            txs = supabase_client.table("transactions").select("*").execute().data
            debts_list = supabase_client.table("debts").select("*").execute().data
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Database error during reports: {str(e)}")
    else:
        txs = mock_transactions
        debts_list = mock_debts
        
    now = datetime.now(timezone.utc)
    
    # Compute aggregates
    total_gain = 0.0
    total_spend = 0.0
    for t in txs:
        amount = float(t.get("amount", 0))
        if t.get("type") == "gain":
            total_gain += amount
        elif t.get("type") == "spend":
            total_spend += amount
            
    # Calculate total accrued interest across all active debts
    total_interest = sum(calculate_debt_interest(d) for d in debts_list)
    
    # 2. Distribute interest and transactions across timeframe buckets
    chart_data = {}
    
    # Helper to initialize chart buckets
    if timeframe == "monthly":
        # Initialize last 12 months in descending order, then reverse for display
        for i in range(12):
            # Calculate year and month offset
            y_offset = (now.month - 1 - i) // 12
            m_offset = (now.month - 1 - i) % 12 + 1
            year = now.year + y_offset
            month = m_offset
            key = f"{year}-{month:02d}"
            label = f"{calendar.month_abbr[month]} {year}"
            chart_data[key] = {
                "key": key,
                "label": label,
                "gain": 0.0,
                "spend": 0.0,
                "interest": 0.0
            }
    else:
        # Initialize last 5 years
        for i in range(5):
            year = now.year - i
            key = str(year)
            chart_data[key] = {
                "key": key,
                "label": key,
                "gain": 0.0,
                "spend": 0.0,
                "interest": 0.0
            }
            
    # Populating Transactions into Buckets
    for t in txs:
        t_date = parse_date(t.get("timestamp"))
        amount = float(t.get("amount", 0))
        t_type = t.get("type")
        
        if timeframe == "monthly":
            key = f"{t_date.year}-{t_date.month:02d}"
        else:
            key = str(t_date.year)
            
        if key in chart_data:
            if t_type == "gain":
                chart_data[key]["gain"] += amount
            elif t_type == "spend":
                chart_data[key]["spend"] += amount
                
    # Populating Debt Interest into Buckets using dynamic allocation
    if timeframe == "monthly":
        # Calculate monthly distribution of interest
        interest_dist = get_monthly_interest_distribution(debts_list, now)
        for k, val in interest_dist.items():
            if k in chart_data:
                chart_data[k]["interest"] = round(val, 2)
    else:
        # Calculate yearly distribution of interest
        interest_dist = get_yearly_interest_distribution(debts_list, now)
        for k, val in interest_dist.items():
            if k in chart_data:
                chart_data[k]["interest"] = round(val, 2)
                
    # Format and sort chart data chronologically
    sorted_chart_keys = sorted(chart_data.keys())
    formatted_chart_data = [chart_data[k] for k in sorted_chart_keys]
    
    return {
        "timeframe": timeframe,
        "total_gain": round(total_gain, 2),
        "total_spend": round(total_spend, 2),
        "total_interest_accrued": round(total_interest, 2),
        "chart_data": formatted_chart_data
    }


def get_monthly_interest_distribution(debts_list, now: datetime) -> dict:
    distribution = {}
    for d in debts_list:
        created_at = parse_date(d.get("created_at"))
        original_amount = float(d.get("original_amount", 0))
        interest_rate = float(d.get("interest_rate", 0))
        
        if original_amount <= 0 or interest_rate <= 0:
            continue
            
        daily_rate = original_amount * (interest_rate / 100.0) / 365.0
        
        # Start iterating month-by-month from creation date
        curr = datetime(created_at.year, created_at.month, 1, tzinfo=timezone.utc)
        while curr <= now:
            # Overlap segment
            start_date = max(created_at, curr)
            _, last_day = calendar.monthrange(curr.year, curr.month)
            end_of_month = datetime(curr.year, curr.month, last_day, 23, 59, 59, tzinfo=timezone.utc)
            end_date = min(now, end_of_month)
            
            if end_date >= start_date:
                days = (end_date - start_date).total_seconds() / 86400.0
                interest = days * daily_rate
                key = f"{curr.year}-{curr.month:02d}"
                distribution[key] = distribution.get(key, 0.0) + interest
                
            # Advance to next month
            if curr.month == 12:
                curr = datetime(curr.year + 1, 1, 1, tzinfo=timezone.utc)
            else:
                curr = datetime(curr.year, curr.month + 1, 1, tzinfo=timezone.utc)
                
    return distribution


def get_yearly_interest_distribution(debts_list, now: datetime) -> dict:
    distribution = {}
    for d in debts_list:
        created_at = parse_date(d.get("created_at"))
        original_amount = float(d.get("original_amount", 0))
        interest_rate = float(d.get("interest_rate", 0))
        
        if original_amount <= 0 or interest_rate <= 0:
            continue
            
        daily_rate = original_amount * (interest_rate / 100.0) / 365.0
        
        curr = datetime(created_at.year, 1, 1, tzinfo=timezone.utc)
        while curr <= now:
            start_date = max(created_at, curr)
            end_of_year = datetime(curr.year, 12, 31, 23, 59, 59, tzinfo=timezone.utc)
            end_date = min(now, end_of_year)
            
            if end_date >= start_date:
                days = (end_date - start_date).total_seconds() / 86400.0
                interest = days * daily_rate
                key = str(curr.year)
                distribution[key] = distribution.get(key, 0.0) + interest
                
            curr = datetime(curr.year + 1, 1, 1, tzinfo=timezone.utc)
            
    return distribution

# Serve static files if the directory exists
try:
    from fastapi.staticfiles import StaticFiles
    static_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static")
    if os.path.exists(static_dir):
        app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")
except Exception as e:
    print(f"Error mounting static files: {e}")
