# APIGateway Reference Platform

Reference architecture for dynamic API Gateway composition using the abstracted helm approach

## Main points

* Use helm as underlying templating mechanism - unlocking loops and conditionals
* Put helm invocation behind the k8s API server with provider-helm
* Abstract it away with XRD and Composition driving provider-helm Release resource

## Benefits
* Benefit from local test run with `helm template .` and catch errors early with
  faster feedback loop
* Functions without Functions - stable Crossplane functionality

## Implementation specifics
* Additional helm packaging layer is required but it is a commodity - different
  environments can adopt different ways to store charts. Lot of prominent services
  can be used for that: from GitHub to ECR, or anything OCI compatible.

## What about Composition Functions?

Abstracted helm approach is experimental design that uses stable Crossplane
functionality with combination of CNCF ecosystem tooling.  We reuse helm templating
for dynamic parts of the managed resource composition. The future implementation
of this dynamic functionality with templating capabilities is targeted to be
based on [Composition Functions](https://docs.crossplane.io/knowledge-base/guides/composition-functions/)
right after they mature to v1beta1.

## End-to-end example

* `claim.yaml`
```yaml
apiVersion: apigateway.upbound.io/v1alpha1
kind: APIGateway
metadata:
  name: upbound-apigateway
spec:
  parameters:
    region: eu-west-1
    resources:
      - path: test
      - path: test2
      - path: test3
        methods:
          - httpMethod: GET
            authorizationType: NONE
            integration:
              - type: HTTP
                integrationHttpMethod: POST
                uri: https://example.com
            integrationResponses:
              - statusCode: "200"
                responseTemplates:
                  application/xml: |
                    #set($inputRoot = $input.path('$'))
                    <?xml version="1.0" encoding="UTF-8"?>
                    <message>
                        $inputRoot.body
                    </message>
            methodResponses:
              - statusCode: "200"
            requestParameters:
              method.request.header.X-Some-Header: true
```

* Assuming the Claim is applied and ready
```sh
 k get -f claim.yaml
NAME                 SYNCED   READY   CONNECTION-SECRET   AGE
upbound-apigateway   True     True                        22m
```

* Application of the claim above results to dynamic control of the set of
  APIGateway resources:
```sh
k get managed
NAME                                                        CHART        VERSION   SYNCED   READY   STATE      REVISION   DESCRIPTION        AGE
release.helm.crossplane.io/upbound-apigateway-98hd6-x4hgc   apigateway   0.12.0    True     True    deployed   1          Install complete   23m

NAME                                                             KIND     PROVIDERCONFIG   SYNCED   READY   AGE
object.kubernetes.crossplane.io/upbound-apigateway-98hd6-vzmlw   Secret   default          True     True    23m

NAME                                                                  READY   SYNCED   EXTERNAL-NAME                    AGE
methodresponse.apigateway.aws.upbound.io/upbound-apigateway-98hd6-0   True    True     agmr-92t5wxv1p8-iszsl8-GET-200   23m

NAME                                                            READY   SYNCED   EXTERNAL-NAME   AGE
resource.apigateway.aws.upbound.io/upbound-apigateway-98hd6-2   True    True     iszsl8          23m
resource.apigateway.aws.upbound.io/upbound-apigateway-98hd6-1   True    True     ep1few          23m
resource.apigateway.aws.upbound.io/upbound-apigateway-98hd6-0   True    True     kbx3o0          23m

NAME                                                                       READY   SYNCED   EXTERNAL-NAME                    AGE
integrationresponse.apigateway.aws.upbound.io/upbound-apigateway-98hd6-0   True    True     agir-92t5wxv1p8-iszsl8-GET-200   23m

NAME                                                               READY   SYNCED   EXTERNAL-NAME               AGE
integration.apigateway.aws.upbound.io/upbound-apigateway-98hd6-0   True    True     agi-92t5wxv1p8-iszsl8-GET   23m

NAME                                                          READY   SYNCED   EXTERNAL-NAME               AGE
method.apigateway.aws.upbound.io/upbound-apigateway-98hd6-0   True    True     agm-92t5wxv1p8-iszsl8-GET   23m

NAME                                                         READY   SYNCED   EXTERNAL-NAME   AGE
restapi.apigateway.aws.upbound.io/upbound-apigateway-98hd6   True    True     92t5wxv1p8      23m
```
* AWS Console representation
<img width="1264" alt="image" src="https://user-images.githubusercontent.com/518532/225043444-57ed8289-b81c-42e6-a91c-53ce97a16a32.png">

