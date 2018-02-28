using BSON

rawproto(io::IO) = readproto(io, Proto.ModelProto())
rawproto(path::String) = open(rawproto, path)

"""
Convert a data type to the corresponding dictionary.
"""
function convert_model(model::Any)
    dict = Dict(f=>get_field(model, f) for f in fieldnames(model))
    return dict
end

"""
Retrieve only the useful information from a AttributeProto
object into a Dict format.
"""
function convert_model(model::Proto.AttributeProto)
    attributes = [:name, :_type, :f, :i, :ints]
    dict = Dict(f=>get_field(model, f) for f in attributes)
    return dict
end

"""
Convert an Array of ValueInfoProto to Array of Dicts.
"""
function convert_model(model::Array{ONNX.Proto.ValueInfoProto,1})
    a = Array{Any, 1}()
    for ele in model
        push!(a, convert_model(ele))
    end
    return a
end

"""
Convert an Array of OperatorSetIdProto to Array of Dicts.
"""
function convert_model(model::Array{ONNX.Proto.OperatorSetIdProto,1})
    a = Array{Any, 1}()
    for ele in model
        push!(a, convert_model(ele))
    end
    return a
end

"""
Convert an Array of StringStringEntryProto to Array of Dicts.
"""
function convert_model(model::Array{ONNX.Proto.StringStringEntryProto,1})
    a = Array{Any, 1}()
    for ele in model
        push!(a, convert_model(ele))
    end
    return a
end

"""
Get the array from a TensorProto object.
"""
function get_array(x::Proto.TensorProto)
  @assert x.data_type == 1 # Float32
  x = reshape(reinterpret(Float32, x.raw_data), x.dims...)
  return permutedims(x, reverse(1:ndims(x)))
end

"""
Convert a ModelProto object to a Model type.
"""
function convert(model::Proto.ModelProto)
    m = Types.Model(model.ir_version,
                convert_model(model.opset_import),
                model.producer_name,
                model.producer_version,
                model.domain, model.model_version, 
                model.doc_string, convert(model.graph),
                convert_model(model.metadata_props))
    return m
end

"""
Convert a GraphProto object to Graph type.
"""
function convert(model::Proto.GraphProto)
    temp = model.initializer
    d = Dict()
    for ele in temp
        d[ele.name] = get_array(ele)
    end
    a = Array{Any, 1}()
    for ele in model.node
        push!(a, convert(ele))
    end
    m = Types.Graph(a,                       
            model.name, 
            d, model.doc_string, 
            convert_model(model.input),
            convert_model(model.output), 
            convert_model(model.value_info))
    return m
end

"""
Convert a Proto.NodeProto to Node type.
"""
function convert(model::Proto.NodeProto)
    m = Types.Node(model.input, 
            model.output, 
            model.name, 
            model.op_type, 
            model.domain,
            convert_model(model.attribute), 
            model.doc_string)
    return m
end

"""
Serialize the weights to a binary format and stores in the
weights.bson file.
"""
function write_weights(model)
    f = readproto(open(model), ONNX.Proto.ModelProto())
    f = f.graph.initializer
    weights = Dict{Symbol, Any}()
    for ele in f
        weights[Symbol(ele.name)] = ONNX.get_array(ele)
    end
    bson("weights.bson", weights)
end

"""
Retrieve the dictionary form the binary file.
""" 
function read_weights()
    return BSON.load("weights.bson")
end
