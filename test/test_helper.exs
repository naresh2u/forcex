ExUnit.start()

Application.ensure_all_started(:poison)

Mox.defmock(Forcex.Api.MockHttp, for: Forcex.Api)
