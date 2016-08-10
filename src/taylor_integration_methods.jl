doc"""`ad!(f, x, order)`

`ad!` calculates the recursion relation for any problem (coded into
function `f`), up to any order of interest. The `TaylorSeries.Taylor1` object
that stores the Taylor coefficients is `x`. Initially, `x` contains only the
0-th order Taylor coefficients of the current system state, and `ad!` "fills"
recursively the high-order derivates back into `x`.
"""
function ad!{T<:Number}(f, x::Array{Taylor1{T},1}, order::Int, params)
    for i::Int in 1:order
        ip1=i+1
        im1=i-1
        x_i = Array{Taylor1{T},1}(length(x))
        for j::Int in eachindex(x)
            x_i[j] = Taylor1( x[j].coeffs[1:i], im1 )
        end
        F = f(x_i, params)
        for j::Int in eachindex(x)
            x[j].coeffs[ip1]=F[j].coeffs[i]/i
        end
    end
end

doc"""`stepsize(x, epsilon)`

This method calculates a time-step size for a TaylorSeries.Taylor1 object `x` using a
prescribed absolute tolerance `epsilon`.
"""
function stepsize{T<:Number}(x::Taylor1{T}, epsilon::T)
    ord = x.order::Int
    h = Inf::T
    for k::Int in [ord-1, ord]
        kinv = 1.0/k
        aux = abs( x.coeffs[k+1] )::T
        h = min(h, (epsilon/aux)^kinv)
    end
    return h
end

doc"""`stepsizeall(state, epsilon)`

This method calculates the overall minimum time-step size for `state`, which is
an array of TaylorSeries.Taylor1, given a prescribed absolute tolerance `epsilon`.
"""
function stepsizeall{T<:Number}(q::Array{Taylor1{T},1}, epsilon::T)
    hh = Inf::T
    for i::Int in eachindex(q)
        h1 = stepsize( q[i], epsilon )::T
        hh = min( hh, h1 )
    end
    return hh
end

doc"""`taylor_propagator(n,my_delta_t,jets...)`

Propagates a tuple of `Taylor1` objects, representing the system state,
to the instant `my_delta_t`, up to order `n`, using the Horner method of summation.
Returns the evaluations as an array. Note this function assumes that the first
component of the state vector is the independent variable."""
function taylor_propagator{T<:Number}(n::Int, my_delta_t::T, jets::Array{Taylor1{T},1})

    sum0 = Array{ typeof(jets[1].coeffs[1]) }( length(jets) )

    sum0[1]=jets[1].coeffs[1]+my_delta_t

    for i::Int in 2:length(jets)
        sum0[i] = jets[i].coeffs[n+1]
        for k in n+1:-1:2
            sum0[i] = jets[i].coeffs[k-1]+sum0[i]*my_delta_t
        end #for k, Horner sum
    end #for i, jets

    return sum0

end

doc"""`taylor_one_step{T<:Number}(f, timestep_method, state::Array{T,1}, abs_tol::T, order::Int)`

This is a general-purpose Taylor one-step iterator for the explicit 1st-order ODE
defined by ẋ=`f`(x) with x=`state` (a `TaylorSeries.Taylor1` array). The Taylor expansion order
is specified by `order`, and `abs_tol` is the absolute tolerance. Time-step
control must be provided by the user via the `timestep_method` argument.
"""
function taylor_one_step{T<:Number}(f, timestep_method, state::Array{T,1}, abs_tol::T, order::Int, params)

    stateT = Array{Taylor1{T},1}(length(state))
    for i::Int in eachindex(state)
        stateT[i] = Taylor1( state[i], order )
    end
    ad!(f, stateT, order, params)
    step = timestep_method(stateT, abs_tol)::T
    new_state = taylor_propagator(order, step, stateT)::Array{T,1}

    return new_state

end

doc"""`taylor_integrator(f, timestep_method, state, time, abs_tol, order, t_max)`

This is a general-purpose Taylor integrator for the explicit 1st-order initial
value problem defined by ẋ=`f`(x) and initial condition `initial_state` (a `TaylorSeries.Taylor1` array).
Returns final state up to time `t_max`. The Taylor expansion order
is specified by `order`, and `abs_tol` is the absolute tolerance. Time-step
control must be provided by the user via the `timestep_method` argument.

NOTE: this integrator assumes that the independent variable is included as the
first component of the `initial_state` array, and its evolution ṫ=1 must be included
in the equations of motion as well.
"""
function taylor_integrator{T<:Number}(f, timestep_method, initial_state::Array{T,1}, abs_tol::T, order::Int, t_max::T)

    state = initial_state::Array{T,1}

    while state[1]::T<t_max

        state = taylor_one_step(f, timestep_method, state, abs_tol, order)::Array{T,1}

    end

    return state

end

doc"""`taylor_integrator!{T<:Number}(f, timestep_method, initial_state::Array{T,1}, abs_tol::T, order::Int, t_max::T, datalog::Array{Array{T,1},1})`

This is a general-purpose Taylor integrator for the explicit 1st-order initial
value problem defined by ẋ=`f`(x) and initial condition `initial_state` (a `T` type array).
Returns final state up to time `t_max`, storing the system history into `datalog`. The Taylor expansion order
is specified by `order`, and `abs_tol` is the absolute tolerance. Time-step
control must be provided by the user via the `timestep_method` argument.

NOTE: this integrator assumes that the independent variable is included as the
first component of the `initial_state` array, and its evolution ṫ=1 must be included
in the equations of motion as well.
"""
function taylor_integrator!{T<:Number}(f, timestep_method, initial_state::Array{T,1}, abs_tol::T, order::Int, t_max::T, datalog::Array{Array{T,1},1}, params...)

    state = initial_state::Array{T,1}

    for i::Int in eachindex(datalog)
        push!(datalog[i], state[i])
    end

    while state[1]::T<t_max

        state = taylor_one_step(f, timestep_method, state, abs_tol, order, params)::Array{T,1}

        for i::Int in eachindex(datalog)
            push!(datalog[i], state[i])
        end

    end

    return state

end

doc"""`taylor_integrator_log(f, timestep_method, state, time, abs_tol, order, t_max)`

This is a general-purpose Taylor integrator for the explicit 1st-order initial
value problem defined by ẋ=`f`(x) and initial condition `initial_state` (a `TaylorSeries.Taylor1` array).
Returns state history for all time steps up to time `t_max`. The Taylor expansion order
is specified by `order`, and `abs_tol` is the absolute tolerance. Time-step
control must be provided by the user via the `timestep_method` argument.

NOTE: this integrator assumes that the independent variable is included as the
first component of the `initial_state` array, and its evolution ṫ=1 must be included
in the equations of motion as well.
"""
function taylor_integrator_log{T<:Number}(f, timestep_method, initial_state::Array{T,2}, abs_tol::T, order::Int, t_max::T)

    state = initial_state::Array{T,2}
    state_log = state::Array{T,2}

    while state[1]::T<t_max

        state = taylor_one_step(f, timestep_method, state, abs_tol, order)'::Array{T,2}
        state_log = vcat(state_log, state)

    end

    return state_log

end

doc"""`taylor_integrator_k{T<:Number}(f, timestep_method, initial_state::Array{T,1}, abs_tol::T, order::Int, t_max::T, datalog::Array{Array{T,1},1}, k_max::Int)`

This is a general-purpose Taylor integrator for the explicit 1st-order initial
value problem defined by ẋ=`f`(x) and initial condition `initial_state` (a `TaylorSeries.Taylor1` array).
Returns final state up to time `t_max`, storing the system history into `datalog`. The Taylor expansion order
is specified by `order`, and `abs_tol` is the absolute tolerance. Time-step
control must be provided by the user via the `timestep_method` argument.

NOTE: this integrator assumes that the independent variable is included as the
first component of the `initial_state` array, and its evolution ṫ=1 must be included
in the equations of motion as well."""
function taylor_integrator_k(f, timestep_method, initial_state::Array{Float64,1},
    abs_tol::Float64, order::Int, t_max::Float64, datalog::Array{Array{Float64,1},1},
    k_max::Int)

    state = initial_state::Array{Float64,1}

    for i::Int in eachindex(datalog)
        push!(datalog[i], state[i])
    end

    k=0

    while (state[1]::Float64<t_max && k<k_max)

        state = taylor_one_step(f, timestep_method, state, abs_tol, order)::Array{Float64,1}

        for i::Int in eachindex(datalog)
            push!(datalog[i], state[i])
        end

        k+=1

    end

    return state

end

doc"""`taylor_one_step_v2!{T<:Number}(f, timestep_method,
    stateT::Array{Taylor1{T},1}, abs_tol::T, order::Int)`

This is a Taylor one-step iterator for the explicit 1st-order ODE
defined by ẋ=`f`(x) with x=`stateT` (a `TaylorSeries.Taylor1{T}` array). The Taylor expansion order
is specified by `order`, and `abs_tol` is the absolute tolerance. Time-step
control must be provided by the user via the `timestep_method` argument.
"""
function taylor_one_step_v2!{T<:Number}(f, timestep_method,
    stateT::Array{Taylor1{T},1}, abs_tol::T, order::Int)

    ad!(f, stateT, order)

    step = timestep_method(stateT, abs_tol)::T
    new_state = taylor_propagator(order, step, stateT)::Array{T,1}

    return new_state

end



doc"""`taylor_integrator_v2!{T<:Number}(f, timestep_method, initial_state::Array{T,1},
    abs_tol::T, order::Int, t_max::T, datalog::Array{Array{T,1},1})`

This is a general-purpose Taylor integrator for the explicit 1st-order initial
value problem defined by ẋ=`f`(x) and initial condition `initial_state` (a `T` type array).
Returns final state up to time `t_max`, storing the system history into `datalog`. The Taylor expansion order
is specified by `order`, and `abs_tol` is the absolute tolerance. Time-step
control must be provided by the user via the `timestep_method` argument.

The main difference between this method and `taylor_integrator!` is that internally,
`ad!` uses a `Taylor1{T}` version of the state vector, instead of a
`T` version of the state vector.

NOTE: this integrator assumes that the independent variable is included as the
first component of the `initial_state` array, and its evolution ṫ=1 must be included
in the equations of motion as well.
"""
function taylor_integrator_v2!{T<:Number}(f, timestep_method, initial_state::Array{T,1},
    abs_tol::T, order::Int, t_max::T, datalog::Array{Array{T,1},1})

    state = initial_state
    stateT = Array{Taylor1{T},1}(length(state))

    for i::Int in eachindex(datalog)
        push!(datalog[i], initial_state[i])
    end

    while state[1]::T<t_max

        for i::Int in eachindex(state)
            stateT[i] = Taylor1( state[i], order )
        end

        state = taylor_one_step_v2!(f, timestep_method, stateT, abs_tol, order)::Array{T,1}

        for i::Int in eachindex(datalog)
            push!(datalog[i], state[i])
        end

    end

    return state

end