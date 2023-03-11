function hedge(portfolio, data)
    borrowing_vec = zeros(length(portfolio.greeks) + 1)
    borrowing_vec[1] = -1
    A = zeros(length(borrowing_vec), length(borrowing_vec))
    A[:, 1] = borrowing_vec

    greeks = ["value"; portfolio.greeks]

    for (j, asset) in enumerate(portfolio.hedging_instruments)
        param = zeros(length(borrowing_vec))
        for (i, greek) in enumerate(greeks)
            param[i] = getfield(asset, Symbol(greek))(data...)
        end
        A[:, 1 + j] = param
    end

    b = [portfolio.N * getfield(portfolio.f, Symbol(x))(data...) for x in greeks]
    return A, b, A\b
end



function backtest(price, freq, portfolio)
    freqlist = convertdata(price, freq)
    borrow = Any[]
    shares = Any[]
    values = []
    B_old = 0
    shares_old = 0
    old_mat = 0

    for (i, S) in enumerate(price)
        T = (length(price) - i) / 365
        if price[i] == freqlist[i] # rebalancing only after period ended

            A, b, mat = hedge(portfolio, [S, T, 0.2])

            vs = [x(S, T, 0.2) for x in getfield.(portfolio.hedging_instruments, :value)]
            value = mat[2:end]' * vs - portfolio.N * portfolio.f.value(S, T, 0.2) - mat[1]
            append!(values,value)
            old_mat = mat


            if any(abs.(mat[2:end]) .> 10^3)
                append!(borrow, B_old)
                push!(shares, shares_old)
            else
            append!(borrow, mat[1])
            push!(shares, mat[2:end])
            B_old = mat[1]
            shares_old = mat[2:end]
            end
        else
            append!(borrow, B_old)
            push!(shares, shares_old)

            vs = [x(S, T, 0.2) for x in getfield.(portfolio.hedging_instruments, :value)]
            value = old_mat[2:end]' * vs - portfolio.N * portfolio.f.value(S, T, 0.2) - old_mat[1]
            append!(values, value)
        end
    end
    shares = reduce(hcat,shares)
    return borrow, shares, values
end
