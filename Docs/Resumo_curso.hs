asc :: Int -> Int -> [Int]
asc n m
    | m < n = []
    | m == n = [m]
    | otherwise = n: asc (n+1) m