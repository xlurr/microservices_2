-- delivery_db: таблица доставок
CREATE TABLE IF NOT EXISTS deliveries (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    order_id INTEGER NOT NULL,
    address VARCHAR(255) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    tracking_id VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_deliveries_user_id ON deliveries(user_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_order_id ON deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON deliveries(status);
CREATE INDEX IF NOT EXISTS idx_deliveries_tracking_id ON deliveries(tracking_id);

-- Функция для обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_deliveries_updated_at ON deliveries;
CREATE TRIGGER update_deliveries_updated_at BEFORE UPDATE ON deliveries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Demo данные
INSERT INTO deliveries (user_id, order_id, address, tracking_id, status) VALUES
    (1, 1, '742 Evergreen Terrace, Springfield, USA', 'TRK001', 'delivered'),
    (2, 2, '31 Spooner Street, Quahog, USA', 'TRK002', 'in_transit'),
    (3, 3, '123 Main Street, Shelbyville, USA', 'TRK003', 'pending')
ON CONFLICT (tracking_id) DO NOTHING;
