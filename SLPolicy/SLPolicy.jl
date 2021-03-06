#= MIT License

Copyright (c) 2017 ParkJunYeong(https://github.com/ParkJunYeong)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.=#

using HDF5
using MXNet
using ArgParse

include("policy.jl")
include("HDF5Provider.jl")

function ParseArgs()
	s = ArgParseSettings(description="AIGo supervised policy trainer")

	@add_arg_table s begin
		"--epoch"
			help = "Training Epoch"
			arg_type = Int
			default = 10
		"--lr"
			help = "Learning Rate"
			arg_type = Float64
			default = 0.003
		"--batch"
			help = "Mini batch size"
			arg_type = Int
			default = 32
		"--train"
			help = "Train data file"
			arg_type = String
			required = true
		"--test"
			help = "Test data file"
			arg_type = String
			required = true
		"--cp"
			help = "Load checkpoint"
			arg_type = Int
			default = 0
		"--speed"
			help = "Print training speed"
			arg_type = Bool
			default = false
		"--out"
			help = "Output directory"
			arg_type = String
			required = true
	end

	return parse_args(ARGS, s)
end

function TrainSLPolicy(epoch::Int64, lr::Float64, mini_batch::Int64, file, test, policy, load_epoch::Int64=0, speed::Bool=false)
	train_states = file["states"]
	train_actions = file["actions"]

	test_states = test["states"]
	test_actions = test["actions"]

	train_provider = HDF5Provider(train_states, train_actions,
				      batch_size=mini_batch)
	test_provider = HDF5Provider(test_states, test_actions,
				     batch_size=mini_batch)

	if load_epoch == 0
		net = CreatePolicyNet()
	elseif isa(load_epoch, Int)
		net = CreatePolicyNet(policy, load_epoch)
	end

	optimizer = mx.SGD(lr=lr, momentum=0.9, weight_decay=0.00001)
	initializer = mx.XavierInitializer(distribution=mx.xv_uniform, regularization=mx.xv_avg, magnitude=1)

	callbacks = Vector{mx.AbstractCallback}()
	push!(callbacks, mx.do_checkpoint(policy, save_epoch_0=true))

	if speed
		push!(callbacks, mx.speedometer())
	end

	mx.fit(net.model, optimizer, 
	       eval_metric=mx.MultiMetric([mx.Accuracy(), mx.ACE()]), train_provider, eval_data=test_provider,
	       n_epoch=epoch, initializer=initializer, callbacks=callbacks)
end

s = ParseArgs()

file = h5open(s["train"], "r")
test = h5open(s["test"], "r")
TrainSLPolicy(s["epoch"], s["lr"], s["batch"], file, test, s["out"], s["cp"], s["speed"])